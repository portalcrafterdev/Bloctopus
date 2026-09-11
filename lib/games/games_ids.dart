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
  /// Nullable on purpose, though it currently holds a value: null is the
  /// documented "no Play Games project" state that [available] branches on,
  /// and setting it back to null is how this build is turned off again
  /// without deleting the wiring.
  // ignore: unnecessary_nullable_for_final_variable_declarations
  static const String? playGamesProjectId = '180890621658';

  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  /// Whether sign in can be attempted on this platform at all.
  static bool get available => _isIOS || playGamesProjectId != null;

  /// Whether any leaderboard exists to submit to or show.
  ///
  /// Per platform, not absolute: the three boards exist in the Play Console
  /// and so are live on Android, and none of them exist in App Store Connect
  /// yet, so on iOS this is false and the button simply does not offer them.
  static bool get leaderboardAvailable =>
      available && GameLeaderboard.values.any((b) => b.id != null);

  /// Whether any achievement exists to unlock or show. Same reasoning as
  /// [leaderboardAvailable]: live on Android, not yet on iOS.
  static bool get achievementsAvailable =>
      available && GameAchievement.values.any((a) => a.id != null);

  /// What the sign in button calls the service it is signing into.
  ///
  /// Named for the product, not the account behind it. "Google" would be true
  /// on Android - Play Games authenticates with a Google account - but it
  /// promises a general Google sign in the game does not do, and it means
  /// nothing on an iPhone, where the account is an Apple one.
  static String get serviceName => _isIOS ? 'Game Center' : 'Play Games';
}

/// The leaderboards the game submits to.
///
/// Three rather than one because they rank different things: a player who is
/// nowhere near the top on score can still be near it on stars, and a board
/// nobody can place on is a board nobody opens twice.
///
/// Android ids come from Play Console > Play Games Services > Leaderboards
/// and are opaque strings. iOS ids are chosen by hand in App Store Connect
/// and do not exist yet, so availability is decided per board and per
/// platform rather than once for all of them.
enum GameLeaderboard {
  /// Cumulative score across every level played. Rises on every clear.
  totalScore(android: 'CgkI2q2v76EFEAIQFQ', ios: null),

  /// How many distinct levels have been finished at least once. Rises only on
  /// a first clear, so replaying never moves it.
  levelsCompleted(android: 'CgkI2q2v76EFEAIQFg', ios: null),

  /// Stars earned across every level, three per level at best. Rises when a
  /// level is beaten better than before.
  starsEarned(android: 'CgkI2q2v76EFEAIQFw', ios: null);

  const GameLeaderboard({required this.android, required this.ios});

  final String? android;
  final String? ios;

  /// The id for the platform in hand, or null where this board does not exist
  /// yet. Null is the whole gate: nothing calls the SDK without one.
  String? get id => GamesIds._isIOS ? ios : android;

  /// The plugin takes both ids on every call and picks by platform itself, so
  /// these hand it an empty string rather than a null for the platform that
  /// is not running.
  String get androidId => android ?? '';
  String get iosId => ios ?? '';

  /// Whether this particular board can be submitted to right now.
  bool get available => GamesIds.available && id != null;
}

/// The achievements the game can unlock.
///
/// Twenty, matching Play Console exactly. The ids come from the console's own
/// `games-ids.xml` export, which is the only place they exist: they are not
/// derivable from the name and a typo in one is silent, because unlocking an
/// achievement the console has never heard of succeeds and does nothing.
///
/// Eleven of the twenty are incremental, with a [steps] target taken from the
/// console's own `AchievementsMetadata.csv`. Play tracks their progress and
/// draws a progress bar; the game reports an absolute running total through
/// `setSteps`, which never reduces existing progress and so is safe to send
/// again on every level completion.
///
/// That is Android only - Game Center has no incremental type - but so is
/// everything here for now, because iOS ids are null: these exist only in
/// Play Console, and Game Center needs the same twenty recreated by hand in
/// App Store Connect before an iPhone can unlock any of them.
enum GameAchievement {
  // -- levels completed ----------------------------------------------------
  /// "Complete your first level."
  firstRipple(android: 'CgkI2q2v76EFEAIQBg', ios: null),

  /// "Complete 10 levels."
  tideWalker(android: 'CgkI2q2v76EFEAIQAQ', ios: null, steps: 10),

  /// "Complete 50 levels."
  reefRunner(android: 'CgkI2q2v76EFEAIQEQ', ios: null, steps: 50),

  /// "Complete 100 levels."
  deepDiver(android: 'CgkI2q2v76EFEAIQEg', ios: null, steps: 100),

  /// "Complete 250 levels."
  trenchCrawler(android: 'CgkI2q2v76EFEAIQBw', ios: null, steps: 250),

  /// "Complete 500 levels."
  abyssDweller(android: 'CgkI2q2v76EFEAIQCQ', ios: null, steps: 500),

  /// "Complete 1000 levels."
  inkSovereign(android: 'CgkI2q2v76EFEAIQDA', ios: null, steps: 1000),

  // -- chapters ------------------------------------------------------------
  /// "Complete every level in Tide Pools." Chapter 1, levels 1 to 100.
  tidePoolsCleared(android: 'CgkI2q2v76EFEAIQBA', ios: null),

  /// "Reach the Abyss in chapter 10." Reaching, not clearing.
  halfwayDown(android: 'CgkI2q2v76EFEAIQAg', ios: null),

  /// "Reach Still Water in chapter 20." Reaching, not clearing. Hidden.
  stillWater(android: 'CgkI2q2v76EFEAIQCw', ios: null),

  // -- stars ---------------------------------------------------------------
  /// "Earn three stars on any level."
  firstLight(android: 'CgkI2q2v76EFEAIQDQ', ios: null),

  /// "Earn 100 stars."
  constellation(android: 'CgkI2q2v76EFEAIQDw', ios: null, steps: 100),

  /// "Earn 500 stars."
  starChart(android: 'CgkI2q2v76EFEAIQEA', ios: null, steps: 500),

  /// "Earn three stars on 50 levels."
  perfectionist(android: 'CgkI2q2v76EFEAIQBQ', ios: null, steps: 50),

  /// "Earn three stars on 200 levels."
  flawlessDepths(android: 'CgkI2q2v76EFEAIQAw', ios: null, steps: 200),

  // -- score ---------------------------------------------------------------
  /// "Reach a total score of 10000."
  tenThousand(android: 'CgkI2q2v76EFEAIQEw', ios: null),

  /// "Reach a total score of 100000."
  sixFigures(android: 'CgkI2q2v76EFEAIQDg', ios: null),

  /// "Reach a total score of 1000000."
  millionaire(android: 'CgkI2q2v76EFEAIQFA', ios: null),

  // -- how you played ------------------------------------------------------
  /// "Clear three lines with a single piece." Hidden. The only one that is
  /// not a threshold against the save: it happens in a single placement and
  /// is fired from the board, not from the level result.
  chainReaction(android: 'CgkI2q2v76EFEAIQCg', ios: null),

  /// "Complete 25 levels without using a booster."
  unaided(android: 'CgkI2q2v76EFEAIQCA', ios: null, steps: 25);

  const GameAchievement({
    required this.android,
    required this.ios,
    this.steps = 0,
  });

  final String? android;
  final String? ios;

  /// The console's "Steps Needed", or zero for a standard achievement.
  final int steps;

  /// Incremental achievements report progress; standard ones just unlock.
  bool get isIncremental => steps > 0;

  /// The id for the platform in hand, or null where it does not exist yet.
  String? get id => GamesIds._isIOS ? ios : android;

  String get androidId => android ?? '';
  String get iosId => ios ?? '';

  /// Whether this one can be unlocked right now.
  bool get available => GamesIds.available && id != null;
}
