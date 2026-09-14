import '../models/save_data.dart' show BoosterId;

/// Merging a device's save with the one Play Games holds.
///
/// Pure Dart on purpose - no Flutter, no plugin - because this is the part
/// that can silently destroy a player's progress and it has to be testable
/// without a device or an account.
///
/// The rule is best-of, field by field, never "newest wins". A timestamp
/// comparison is the obvious design and it is wrong here: a player who opens
/// the game on a second phone, plays one level offline and then signs in has
/// the *newer* save and the *smaller* one. Taking the newest would delete
/// nine hundred levels of progress and there would be no way back. Taking the
/// best of each field cannot lose anything on either side.
///
/// What that costs is boosters. A player with 3 Rewinds on each of two phones
/// ends up with 3 rather than 6, and one who spends 3 on one phone keeps the 3
/// on the other. Boosters are not bought with money in this game, so the worst
/// case is a player keeping a booster they had already used - which is the
/// right way round for the mistake to fall.
Map<String, dynamic> mergeSaveJson({
  required Map<String, dynamic> local,
  required Map<String, dynamic> cloud,
}) {
  int biggest(String key) {
    final a = (local[key] as num?)?.toInt() ?? 0;
    final b = (cloud[key] as num?)?.toInt() ?? 0;
    return a > b ? a : b;
  }

  // Stars are per level, so this is the one field where neither side is
  // wholly better: a player can have three stars on level 4 here and on
  // level 9 there. Merging by level keeps both.
  final stars = <String, int>{};
  for (final side in <Map<String, dynamic>>[local, cloud]) {
    final raw = (side['stars'] as Map?) ?? const <String, dynamic>{};
    for (final e in raw.entries) {
      final level = e.key.toString();
      final value = (e.value as num?)?.toInt() ?? 0;
      final held = stars[level] ?? 0;
      if (value > held) stars[level] = value;
    }
  }

  final boosters = <String, int>{};
  for (final id in BoosterId.all) {
    final a = ((local['boosters'] as Map?)?[id] as num?)?.toInt() ?? 3;
    final b = ((cloud['boosters'] as Map?)?[id] as num?)?.toInt() ?? 3;
    boosters[id] = a > b ? a : b;
  }

  // Derived rather than trusted. `levelsCompleted` is a counter kept
  // alongside `stars`, and after a merge the two can disagree - a level
  // starred only in the cloud copy is a completion the local counter never
  // saw. The starred levels are the ground truth, and the stored counter is
  // kept only if it is somehow higher, so a save that predates star tracking
  // is not punished.
  final counted = stars.length;
  final stored = biggest('levelsCompleted');

  return <String, dynamic>{
    'version': biggest('version'),
    'currentLevel': biggest('currentLevel'),
    'stars': stars,
    'boosters': boosters,
    // Settings are a property of the phone, not of the account. Music volume
    // and haptics should not follow a player onto a tablet, and a cloud copy
    // written by a device with sound off must not silence this one.
    'settings': local['settings'] ?? cloud['settings'],
    'totalScore': biggest('totalScore'),
    'levelsCompleted': counted > stored ? counted : stored,
    'unaidedCompletions': biggest('unaidedCompletions'),
  };
}
