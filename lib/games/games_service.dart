import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import 'achievements.dart';
import 'games_ids.dart';

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
/// There is deliberately no sign out. Play Games v2 removed programmatic sign
/// out, and Game Center never had it - both are properties of the device
/// account, and the player changes them in the Play Games app or in iOS
/// Settings. A button that claimed otherwise would do nothing.
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


  /// Subscribes to the platform's own view of who is signed in.
  ///
  /// Called from the splash screen alongside the ads. Not awaited: the stream
  /// answers when the platform is ready, which on a cold start is after the
  /// first frame.
  Future<void> init() async {
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

  @visibleForTesting
  void debugReset() {
    _sub?.cancel();
    _sub = null;
    _started = false;
    _signingIn = false;
    _lastSubmitted.clear();
    _unlocked.clear();
    _lastSteps.clear();
    player.value = null;
  }
}
