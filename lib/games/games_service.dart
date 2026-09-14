import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/save_data.dart';

import 'achievements.dart';
import 'games_ids.dart';
import 'save_merge.dart';

/// The signed in player, in terms this app owns.
///
/// [PlayerData] is the plugin's type and carries a base64 string for the
/// avatar. Decoding it once here keeps that cost out of `build`, and keeps
/// `games_services` from leaking into the widget layer.
class GamesPlayer {
  final String name;
  final Uint8List? icon;

  const GamesPlayer({required this.name, this.icon});

  factory GamesPlayer._from(PlayerData data) =>
      GamesPlayer(name: data.displayName, icon: _decode(data.iconImage));

  static Uint8List? _decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      // An avatar is decoration. A malformed one must not cost a sign in.
      return null;
    }
  }
}

/// Play Games on Android, Game Center on iOS, behind one interface.
///
/// Shaped like [AdService] and for the same reason: the game does not know
/// this exists. Nothing here throws into a screen and nothing here blocks
/// play. Every entry point degrades to "not signed in", which is a state the
/// UI has to handle anyway.
///
/// There is no sign out, because neither platform has one: Play Games v2
/// removed programmatic sign out and Game Center never had it. The account
/// belongs to the device, and only the Play Games app or iOS Settings can
/// release it.
///
/// What there is instead is [disconnect], which does the part the game owns -
/// forget the player, stop syncing, stop submitting, and stay that way across
/// launches. The button is worded for what that actually is rather than
/// borrowing a word the platform will not honour.
class GamesService {
  GamesService._();

  static final GamesService instance = GamesService._();

  /// The current player, or null when signed out. Widgets listen to this
  /// rather than asking, because sign in can also happen without them: both
  /// platforms restore a previous session on their own at launch.
  final ValueNotifier<GamesPlayer?> player = ValueNotifier<GamesPlayer?>(null);

  bool get signedIn => player.value != null;

  StreamSubscription<PlayerData?>? _sub;
  bool _started = false;
  bool _signingIn = false;

  bool get signingIn => _signingIn;

  /// The last value submitted per board, so finishing a level that moved none
  /// of them does not spend three network calls. Absent rather than zero, so
  /// a genuine first submission of zero still goes.
  final Map<GameLeaderboard, int> _lastSubmitted = <GameLeaderboard, int>{};

  @visibleForTesting
  bool debugDisabled = false;

  /// Whether the player has disconnected the game from their account on this
  /// device. Persisted separately from the save so that wiping progress and
  /// disconnecting stay independent of each other.
  static const String _optOutKey = 'blocktopus_games_opt_out';

  bool _optedOut = false;

  bool get optedOut => _optedOut;

  /// Disconnects this device from the account.
  ///
  /// Not a sign out, and the button does not call it one. Play Games v2 has no
  /// programmatic sign out and Game Center never had one - the account belongs
  /// to the device, and only the Play Games app or iOS Settings can release
  /// it. What this does is everything the game itself controls: it forgets the
  /// player, stops syncing progress, stops submitting scores, and does not
  /// subscribe again on the next launch.
  ///
  /// The opt out has to persist. Without it the platform restores the session
  /// at the next cold start and the player finds themselves connected again,
  /// which is worse than having no button at all.
  ///
  /// Nothing is deleted. The snapshot stays in the account and the local save
  /// stays on the phone, so connecting again merges them back together.
  Future<void> disconnect() async {
    _optedOut = true;
    await _sub?.cancel();
    _sub = null;
    _started = false;
    _lastSubmitted.clear();
    _unlocked.clear();
    _lastSteps.clear();
    player.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_optOutKey, true);
    } catch (_) {
      // The disconnect still holds for this session; only its memory is lost.
    }
  }

  /// Undoes [disconnect], so the sign in key works again after one.
  Future<void> _clearOptOut() async {
    _optedOut = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_optOutKey);
    } catch (_) {}
  }

  /// Subscribes to the platform's own view of who is signed in.
  ///
  /// Called from the splash screen alongside the ads. Not awaited: the stream
  /// answers when the platform is ready, which on a cold start is after the
  /// first frame.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _optedOut = prefs.getBool(_optOutKey) ?? false;
    } catch (_) {
      _optedOut = false;
    }
    // A player who disconnected stays disconnected across launches. This is
    // the line that makes the button mean anything.
    if (_optedOut) return;
    if (_started || debugDisabled || !GamesIds.available) return;
    _started = true;
    try {
      _sub = GameAuth.player.listen(
        (data) => player.value = data == null ? null : GamesPlayer._from(data),
        // The Android side reports "not authenticated" as a stream error
        // rather than a null. Both mean signed out.
        onError: (_) => player.value = null,
      );
    } catch (_) {
      _started = false;
    }
  }

  /// Signs in, showing the platform's own UI. Returns whether it worked.
  ///
  /// The plugin reports failure by throwing a [PlatformException], so a call
  /// that returns at all succeeded. [player] catches up a moment later over
  /// the stream, which is what the button actually rebuilds on.
  Future<bool> signIn() async {
    if (debugDisabled || !GamesIds.available || _signingIn) return false;
    // Asking to sign in is the undo for [disconnect]. Without this the opt out
    // would survive the tap and the key would appear to do nothing.
    if (_optedOut) {
      await _clearOptOut();
      await init();
    }
    _signingIn = true;
    try {
      // The player is inside a Google or Apple sheet for as long as they want
      // to be, so the timeout is generous. It exists only so a sign in that
      // never comes back cannot leave a spinner on screen forever.
      await GameAuth.signIn().timeout(const Duration(minutes: 2));
      return true;
    } catch (_) {
      // No Play Services, a project id that does not match the signing
      // certificate, a cancelled sheet, or no network. None of them are worth
      // distinguishing to the player.
      return false;
    } finally {
      _signingIn = false;
    }
  }

  /// Submits the player's progress to every leaderboard that exists.
  ///
  /// Called on level completion. Silent by design: a player who is not signed
  /// in has not opted into any of this, and telling them what they are
  /// missing every time they finish a level would be nagging.
  ///
  /// The three boards move at different rates - score changes on every clear,
  /// levels completed only on a first clear, stars only on an improvement -
  /// so each is deduped separately and an unchanged one costs nothing. They
  /// go together rather than in sequence because a slow one must not hold up
  /// the others, and nothing is waiting on the result.
  Future<void> submitProgress({
    required int totalScore,
    required int levelsCompleted,
    required int starsEarned,
  }) async {
    await Future.wait(<Future<void>>[
      _submit(GameLeaderboard.totalScore, totalScore),
      _submit(GameLeaderboard.levelsCompleted, levelsCompleted),
      _submit(GameLeaderboard.starsEarned, starsEarned),
    ]);
  }

  Future<void> _submit(GameLeaderboard board, int value) async {
    if (debugDisabled || !signedIn || !board.available) return;
    final last = _lastSubmitted[board];
    if (last != null && value <= last) return;
    _lastSubmitted[board] = value;
    try {
      await Leaderboards.submitScore(
        score: Score(
          androidLeaderboardID: board.androidId,
          iOSLeaderboardID: board.iosId,
          value: value,
        ),
      );
    } catch (_) {
      // Let the next completed level try again rather than stranding this one
      // board a level behind for the rest of the session.
      _lastSubmitted.remove(board);
    }
  }

  /// Achievements already unlocked this session, so a trigger that fires on
  /// every level completion - and most of them do, because they are threshold
  /// tests against a running total - only ever costs one network call.
  ///
  /// Session scoped rather than saved: the platform is the real record of
  /// what is unlocked, and re-unlocking something is harmless.
  final Set<GameAchievement> _unlocked = <GameAchievement>{};

  /// The last step count reported per incremental achievement, so a level
  /// that moved none of them costs nothing.
  final Map<GameAchievement, int> _lastSteps = <GameAchievement, int>{};

  /// Reports everything the save has earned.
  ///
  /// Called on level completion beside [submitProgress]. The rules live in
  /// `achievements.dart`; this only carries the answer to the platform, and
  /// splits it the way the two Play APIs need: standard achievements unlock,
  /// incremental ones set an absolute step count.
  Future<void> report(AchievementProgress progress) async {
    if (progress.isEmpty) return;
    await Future.wait(<Future<void>>[
      ...progress.unlock.map(unlock),
      ...progress.steps.entries.map((e) => _setSteps(e.key, e.value)),
    ]);
  }

  Future<void> _setSteps(GameAchievement achievement, int value) async {
    if (debugDisabled || !signedIn || !achievement.available) return;
    if (!achievement.isIncremental || value <= 0) return;
    final last = _lastSteps[achievement];
    if (last != null && value <= last) return;
    _lastSteps[achievement] = value;
    try {
      // Absolute, not a delta: setSteps never reduces existing progress, so
      // re-sending the same total is safe and a missed report catches up on
      // its own next time. increment() would double count instead.
      await Achievements.setSteps(
        achievement: Achievement(
          androidID: achievement.androidId,
          iOSID: achievement.iosId,
          steps: value,
        ),
      );
    } catch (_) {
      // Android only. On iOS this throws every time, which is why the guard
      // above is availability rather than platform: iOS ids are null, so
      // nothing reaches here at all.
      _lastSteps.remove(achievement);
    }
  }

  /// Unlocks a standard achievement, at most once per session.
  ///
  /// Silent like everything else here. Unlocking one the console has never
  /// heard of also succeeds and does nothing, so a wrong id cannot be caught
  /// at runtime - only by the test that checks the ids against the console's
  /// own export.
  Future<void> unlock(GameAchievement achievement) async {
    if (debugDisabled || !signedIn || !achievement.available) return;
    if (!_unlocked.add(achievement)) return;
    try {
      await Achievements.unlock(
        achievement: Achievement(
          androidID: achievement.androidId,
          iOSID: achievement.iosId,
          percentComplete: 100,
        ),
      );
    } catch (_) {
      // Let a later level try again rather than losing it for the session.
      _unlocked.remove(achievement);
    }
  }

  /// Opens the platform's achievements screen. Returns whether it opened.
  Future<bool> showAchievements() async {
    if (debugDisabled || !signedIn || !GamesIds.achievementsAvailable) {
      return false;
    }
    try {
      await Achievements.showAchievements();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens the platform's leaderboard screen. Returns whether it opened.
  ///
  /// Deliberately passes no id, which both platforms read as "show the list".
  /// There are three boards and no way to know which one the player came to
  /// look at, so picking one for them would be guessing.
  Future<bool> showLeaderboard() async {
    if (debugDisabled || !signedIn || !GamesIds.leaderboardAvailable) {
      return false;
    }
    try {
      await Leaderboards.showLeaderboards();
      return true;
    } catch (_) {
      return false;
    }
  }

  // -- cloud save -----------------------------------------------------------

  /// The snapshot name. One save slot, not a list: this game has a single
  /// linear progression, so a player choosing between saves would be choosing
  /// between two versions of the same thing.
  ///
  /// It must never change. Renaming it strands every existing snapshot under
  /// the old name, and the game would read that as a player with no progress.
  static const String _snapshot = 'blocktopus_progress';

  /// Whether a sync is in flight, so a level finished while one is running
  /// does not start a second and race it.
  bool _syncing = false;

  /// Stands in for the account's snapshot store.
  ///
  /// There is no platform behind the channel in a test, so without these the
  /// only reachable path is "the cloud could not be reached" - which is the
  /// one path where nothing is allowed to happen. The whole point of the
  /// feature is the other one: sign out and the device is cleared, sign in
  /// and the account hands it back. That has to be testable.
  @visibleForTesting
  Future<String?> Function()? debugLoadSnapshot;
  @visibleForTesting
  Future<void> Function(String data)? debugSaveSnapshot;

  Future<String?> _loadSnapshot() {
    final fake = debugLoadSnapshot;
    return fake != null ? fake() : GamesServices.loadGame(name: _snapshot);
  }

  Future<void> _saveSnapshot(String data) {
    final fake = debugSaveSnapshot;
    return fake != null
        ? fake(data)
        : GamesServices.saveGame(data: data, name: _snapshot);
  }

  /// Pulls the account's save, merges it into [save], and pushes the result.
  ///
  /// Called when a player signs in and on every level completion. The merge is
  /// in `save_merge.dart` and is best-of per field, so neither side can lose
  /// progress - see the note there on why "newest wins" is the wrong rule.
  ///
  /// Silent, like everything else here. A player who is not signed in, or is
  /// offline, or whose console has saved games switched off, keeps playing
  /// against local storage and never learns any of those words.
  /// TEMPORARY. Prints what the sync did, so it can be watched over logcat
  /// while the feature is being proved on a device. Remove once it is trusted:
  /// the sync is silent on purpose, and a player's progress is not something
  /// to narrate into the system log.
  static const bool _traceSync = true;

  void _trace(String message) {
    if (_traceSync) debugPrint('[cloudsave] $message');
  }

  /// Returns true only when the account's copy is known to hold the merged
  /// progress. Most callers fire this and forget it, but disconnecting has to
  /// know: it wipes the device afterwards, and doing that on a push that never
  /// landed would destroy the only copy there was.
  Future<bool> syncSave(SaveData save) async {
    if (debugDisabled || !signedIn || _syncing) return false;
    _syncing = true;
    try {
      final local = save.toJson();
      _trace('start: local level ${local['currentLevel']}');

      Map<String, dynamic>? cloud;
      try {
        final raw = await _loadSnapshot();
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) cloud = decoded.cast<String, dynamic>();
        }
        _trace(
          cloud == null
              ? 'pull: no snapshot yet'
              : 'pull: cloud level ${cloud['currentLevel']}, ${cloud['levelsCompleted']} cleared',
        );
      } catch (e) {
        _trace('pull FAILED: $e');
        // No snapshot yet is the ordinary first run, and the plugin reports it
        // the same way it reports a failure. Either way the local save is the
        // only copy, and pushing it is exactly right.
        cloud = null;
      }

      final merged = cloud == null
          ? local
          : mergeSaveJson(local: local, cloud: cloud);

      // Apply before pushing. If the push fails the player still has the
      // merged progress on the device, which is the half that matters.
      if (cloud != null) await save.applyJson(merged);

      try {
        await _saveSnapshot(jsonEncode(merged));
        _trace(
          'push OK: level ${merged['currentLevel']}, ${merged['levelsCompleted']} cleared',
        );
        return true;
      } catch (e) {
        _trace('push FAILED: $e');
        return false;
      }
    } finally {
      _syncing = false;
    }
  }

  @visibleForTesting
  void debugReset() {
    _sub?.cancel();
    _sub = null;
    _started = false;
    _signingIn = false;
    _syncing = false;
    _lastSubmitted.clear();
    _unlocked.clear();
    _lastSteps.clear();
    player.value = null;
    _optedOut = false;
    debugLoadSnapshot = null;
    debugSaveSnapshot = null;
  }
}
