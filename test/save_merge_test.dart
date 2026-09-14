import 'package:blocktopus/games/save_merge.dart';
import 'package:blocktopus/models/save_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Merging the device's save with the one Play Games holds.
///
/// The reason this file is long for a function this small: it is the only
/// place in the game that can delete a player's progress outright, and the
/// failure is silent and permanent. A wrong merge does not crash - it just
/// hands back a smaller save, writes it to the cloud, and the old one is gone.
void main() {
  Map<String, dynamic> save({
    int currentLevel = 1,
    Map<String, int> stars = const <String, int>{},
    Map<String, int>? boosters,
    int totalScore = 0,
    int levelsCompleted = 0,
    int unaidedCompletions = 0,
    Map<String, dynamic>? settings,
  }) => <String, dynamic>{
    'version': 1,
    'currentLevel': currentLevel,
    'stars': stars,
    'boosters':
        boosters ??
        <String, int>{
          BoosterId.undo: 3,
          BoosterId.hammer: 3,
          BoosterId.refresh: 3,
        },
    'settings': settings ?? <String, dynamic>{'sfx': true},
    'totalScore': totalScore,
    'levelsCompleted': levelsCompleted,
    'unaidedCompletions': unaidedCompletions,
  };

  test('a fresh install takes everything from the cloud', () {
    // The case the owner actually hit: sign out, sign in again, and the
    // levels were gone. A new device has a default save, so every field here
    // has to come from the cloud side.
    final merged = mergeSaveJson(
      local: save(),
      cloud: save(
        currentLevel: 412,
        stars: <String, int>{'1': 3, '2': 2, '411': 3},
        totalScore: 128400,
        levelsCompleted: 411,
        unaidedCompletions: 12,
      ),
    );

    expect(merged['currentLevel'], 412);
    expect(merged['totalScore'], 128400);
    expect(merged['levelsCompleted'], 411);
    expect(merged['unaidedCompletions'], 12);
    expect((merged['stars'] as Map).length, 3);
  });

  test('progress made offline before signing in is not thrown away', () {
    // The reason this merges rather than letting the cloud win. This player
    // has the newer save and the smaller one; "newest wins" would delete the
    // other four hundred levels.
    final merged = mergeSaveJson(
      local: save(
        currentLevel: 5,
        stars: <String, int>{'4': 3},
        totalScore: 90,
      ),
      cloud: save(
        currentLevel: 412,
        stars: <String, int>{'1': 3},
        totalScore: 128400,
      ),
    );

    expect(merged['currentLevel'], 412, reason: 'the cloud was further on');
    expect(
      (merged['stars'] as Map)['4'],
      3,
      reason: 'the level played offline lost its stars',
    );
    expect((merged['stars'] as Map)['1'], 3);
  });

  test('stars are merged per level, not per save', () {
    // Neither side is wholly better: each has a level the other does not, and
    // they disagree about a level they share.
    final merged = mergeSaveJson(
      local: save(stars: <String, int>{'1': 3, '2': 1, '7': 2}),
      cloud: save(stars: <String, int>{'1': 1, '2': 3, '9': 3}),
    );

    final stars = merged['stars'] as Map;
    expect(stars['1'], 3, reason: 'the better of the two was not kept');
    expect(stars['2'], 3);
    expect(stars['7'], 2, reason: 'a level only this device had was dropped');
    expect(stars['9'], 3, reason: 'a level only the cloud had was dropped');
  });

  test('levels completed is counted from the stars, not trusted', () {
    // After a merge the stored counter is stale on both sides: each was
    // counting only its own levels. The starred levels are the truth.
    final merged = mergeSaveJson(
      local: save(stars: <String, int>{'1': 3, '2': 3}, levelsCompleted: 2),
      cloud: save(stars: <String, int>{'3': 3, '4': 3}, levelsCompleted: 2),
    );

    expect(
      merged['levelsCompleted'],
      4,
      reason: 'four distinct levels are starred, so four were completed',
    );
  });

  test('a counter higher than the star count survives', () {
    // A save written before stars were tracked per level would otherwise be
    // demoted to zero by the rule above.
    final merged = mergeSaveJson(
      local: save(levelsCompleted: 40),
      cloud: save(stars: <String, int>{'1': 3}),
    );
    expect(merged['levelsCompleted'], 40);
  });

  test('boosters take the higher count', () {
    final merged = mergeSaveJson(
      local: save(
        boosters: <String, int>{
          BoosterId.undo: 7,
          BoosterId.hammer: 0,
          BoosterId.refresh: 2,
        },
      ),
      cloud: save(
        boosters: <String, int>{
          BoosterId.undo: 1,
          BoosterId.hammer: 5,
          BoosterId.refresh: 2,
        },
      ),
    );

    final boosters = merged['boosters'] as Map;
    expect(boosters[BoosterId.undo], 7);
    expect(boosters[BoosterId.hammer], 5);
    expect(boosters[BoosterId.refresh], 2);
  });

  test('settings stay on the device they were set on', () {
    // Volume and haptics belong to the phone. A cloud copy written by a
    // device with the sound off must not silence this one.
    final merged = mergeSaveJson(
      local: save(settings: <String, dynamic>{'sfx': true, 'music': true}),
      cloud: save(settings: <String, dynamic>{'sfx': false, 'music': false}),
    );

    expect((merged['settings'] as Map)['sfx'], true);
    expect((merged['settings'] as Map)['music'], true);
  });

  test('merging is symmetrical', () {
    // Which side is called "local" must not change the answer for anything
    // except settings. If it does, two devices syncing in a different order
    // end up with different saves, and they will fight over the cloud copy
    // forever.
    final a = save(
      currentLevel: 5,
      stars: <String, int>{'1': 3, '4': 2},
      totalScore: 900,
      unaidedCompletions: 4,
    );
    final b = save(
      currentLevel: 412,
      stars: <String, int>{'1': 1, '9': 3},
      totalScore: 128400,
      unaidedCompletions: 1,
    );

    final ab = mergeSaveJson(local: a, cloud: b);
    final ba = mergeSaveJson(local: b, cloud: a);

    for (final key in <String>[
      'currentLevel',
      'totalScore',
      'levelsCompleted',
      'unaidedCompletions',
    ]) {
      expect(ab[key], ba[key], reason: '$key depends on the argument order');
    }
    expect(ab['stars'], ba['stars']);
    expect(ab['boosters'], ba['boosters']);
  });

  test('merging a save with itself changes nothing', () {
    // The common case by far: one device, syncing repeatedly. If this drifts,
    // every launch rewrites the cloud copy for no reason.
    final one = save(
      currentLevel: 412,
      stars: <String, int>{'1': 3, '2': 2},
      totalScore: 128400,
      levelsCompleted: 2,
      unaidedCompletions: 12,
    );

    final merged = mergeSaveJson(
      local: one,
      cloud: Map<String, dynamic>.from(one),
    );

    expect(merged['currentLevel'], one['currentLevel']);
    expect(merged['totalScore'], one['totalScore']);
    expect(merged['unaidedCompletions'], one['unaidedCompletions']);
    expect(merged['stars'], one['stars']);
    expect(merged['levelsCompleted'], 2);
  });

  test('a merged blob is something SaveData can read back', () {
    // The merge writes JSON by hand, so nothing checks its shape at compile
    // time. If a key is misspelled the field silently reads as a default,
    // which looks exactly like lost progress.
    final merged = mergeSaveJson(
      local: save(),
      cloud: save(
        currentLevel: 412,
        stars: <String, int>{'1': 3, '2': 2},
        totalScore: 128400,
        unaidedCompletions: 12,
      ),
    );

    final data = SaveData.fromJson(merged);
    expect(data.currentLevel, 412);
    expect(data.totalScore, 128400);
    expect(data.unaidedCompletions, 12);
    expect(data.starsFor(1), 3);
    expect(data.starsFor(2), 2);
    expect(data.totalStars, 5);
  });
}
