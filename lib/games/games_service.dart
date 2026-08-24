import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

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

  /// The last total submitted, so finishing a level that scored nothing new
  /// does not spend a network call. -1 rather than 0 so a first submission of
  /// zero still goes.
  int _lastSubmitted = -1;

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

  /// Submits the running total to the leaderboard.
  ///
  /// Called on level completion. Silent by design: a player who is not signed
  /// in has not opted into any of this, and telling them what they are
  /// missing every time they finish a level would be nagging.
  Future<void> submitTotalScore(int score) async {
    if (debugDisabled || !signedIn || !GamesIds.leaderboardAvailable) return;
    if (score <= _lastSubmitted) return;
    _lastSubmitted = score;
    try {
      await Leaderboards.submitScore(
        score: Score(
          androidLeaderboardID: GamesIds.androidLeaderboard,
          iOSLeaderboardID: GamesIds.iosLeaderboard,
          value: score,
        ),
      );
    } catch (_) {
      // Let the next completed level try again rather than stranding the
      // total one level behind for the rest of the session.
      _lastSubmitted = -1;
    }
  }

  /// Opens the platform's leaderboard screen. Returns whether it opened.
  Future<bool> showLeaderboard() async {
    if (debugDisabled || !signedIn || !GamesIds.leaderboardAvailable) {
      return false;
    }
    try {
      await Leaderboards.showLeaderboards(
        androidLeaderboardID: GamesIds.androidLeaderboard,
        iOSLeaderboardID: GamesIds.iosLeaderboard,
      );
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
    _lastSubmitted = -1;
    player.value = null;
  }
}
