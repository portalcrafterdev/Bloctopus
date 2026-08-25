import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Every Play Games and Game Center identifier the game uses.
///
/// The two platforms are not symmetrical, and that is the reason this file
/// exists rather than a handful of constants next to the code that needs
/// them.
///
/// Game Center needs no project id at all: the entitlement in
/// `ios/Runner/Runner.entitlements` is the whole configuration, and a signed
/// build on a device with an Apple ID can sign in immediately. Play Games
/// needs a numeric project id, created in the Play Console, declared in the
/// Android manifest, and tied to the SHA-1 of the certificate that signed the
/// build. Until that exists the SDK has nothing to talk to.
///
/// So [available] is what the rest of the code asks before touching any of
/// it. Nothing here throws, and nothing calls into the plugin while it is
/// false: an unconfigured Play Games SDK does not fail quietly, it puts a
/// Google dialog in front of the player.
class GamesIds {
  const GamesIds._();

  /// The Play Games project id, from Play Console > Play Games Services >
  /// Configuration. A twelve digit number, not the AdMob app id and not the
  /// application id.
  ///
  /// Paste it here **and** in `android/app/src/main/res/values/strings.xml`,
  /// which is where the SDK actually reads it from. A test asserts the two
  /// agree, because nothing at runtime would tell you they had drifted: sign
  /// in would simply fail with a generic error.
  static const String? playGamesProjectId = null;

  /// Leaderboard ids. Android's is issued by the Play Console and looks like
  /// `CgkI1a2b3c4dEAIQAQ`; iOS's is chosen by you in App Store Connect, and
  /// a reverse-DNS string such as `com.portalcrafter.blocktopus.total_score` is the
  /// convention.
  ///
  /// Both are null until the leaderboards are created. Sign in does not need
  /// them, so the button works before they exist.
  static const String? androidLeaderboardId = null;
  static const String? iosLeaderboardId = null;

  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  /// Whether sign in can be attempted on this platform at all.
  static bool get available => _isIOS || playGamesProjectId != null;

  /// Whether there is a leaderboard to submit to or show.
  static bool get leaderboardAvailable =>
      available && (_isIOS ? iosLeaderboardId : androidLeaderboardId) != null;

  /// The plugin takes both ids on every call and picks by platform itself, so
  /// these hand it empty strings rather than nulls for the platform that is
  /// not running.
  static String get androidLeaderboard => androidLeaderboardId ?? '';
  static String get iosLeaderboard => iosLeaderboardId ?? '';

  /// What the sign in button calls the service it is signing into.
  ///
  /// Named for the product, not the account behind it. "Google" would be true
  /// on Android - Play Games authenticates with a Google account - but it
  /// promises a general Google sign in the game does not do, and it means
  /// nothing on an iPhone, where the account is an Apple one.
  static String get serviceName => _isIOS ? 'Game Center' : 'Play Games';
}
