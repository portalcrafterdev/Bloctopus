import 'package:blocktopus/games/achievements.dart';
import 'package:blocktopus/games/games_ids.dart';
import 'package:blocktopus/models/level.dart';
import 'package:blocktopus/models/save_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The achievement rules, tested without a platform channel.
///
/// Unlocking one at the wrong moment cannot be undone - the player sees a
/// reward for something they did not do - so every threshold is asserted on
/// both sides of its boundary.
void main() {
  // The rules themselves are pure, but recordResult persists, so that one
  // test needs the prefs channel to exist.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  /// A save with [n] levels completed, each at [starsEach].
  SaveData withLevels(int n, {int starsEach = 1, int? currentLevel}) {
    return SaveData(
      currentLevel: currentLevel ?? (n + 1).clamp(1, kLevelCount),
      stars: <int, int>{for (var i = 1; i <= n; i++) i: starsEach},
      levelsCompleted: n,
    );
  }

  bool unlocks(SaveData save, GameAchievement a) =>
      achievementProgress(save).unlock.contains(a);

  int? stepsFor(SaveData save, GameAchievement a) =>
      achievementProgress(save).steps[a];

  group('levels completed', () {
    test('First Ripple needs one level', () {
      expect(unlocks(SaveData(), GameAchievement.firstRipple), isFalse);
      expect(unlocks(withLevels(1), GameAchievement.firstRipple), isTrue);
    });

    test('the ladder reports progress against its own target', () {
      final save = withLevels(60);
      // Past its target, so capped at it. Play rejects a step count above the
      // configured maximum.
      expect(stepsFor(save, GameAchievement.tideWalker), 10);
      expect(stepsFor(save, GameAchievement.reefRunner), 50);
      // Short of its target, so the true running count.
      expect(stepsFor(save, GameAchievement.deepDiver), 60);
      expect(stepsFor(save, GameAchievement.trenchCrawler), 60);
      expect(stepsFor(save, GameAchievement.inkSovereign), 60);
    });

    test('the targets are the ones in the console csv', () {
      expect(GameAchievement.tideWalker.steps, 10);
      expect(GameAchievement.reefRunner.steps, 50);
      expect(GameAchievement.deepDiver.steps, 100);
      expect(GameAchievement.trenchCrawler.steps, 250);
      expect(GameAchievement.abyssDweller.steps, 500);
      expect(GameAchievement.inkSovereign.steps, 1000);
    });
  });

  group('chapters', () {
    test('Tide Pools Cleared needs every level in chapter one', () {
      expect(
        unlocks(withLevels(99), GameAchievement.tidePoolsCleared),
        isFalse,
        reason: '99 of 100 is not every level',
      );
      expect(unlocks(withLevels(100), GameAchievement.tidePoolsCleared), isTrue);
    });

    test('Tide Pools Cleared is about chapter one only', () {
      // Reaching level 150 without finishing chapter 1 is impossible in the
      // real unlock rules, but the achievement must not be satisfied by
      // progress alone.
      final save = SaveData(
        currentLevel: 150,
        stars: <int, int>{for (var i = 101; i <= 150; i++) i: 3},
      );
      expect(unlocks(save, GameAchievement.tidePoolsCleared), isFalse);
    });

    test('Halfway Down is reaching chapter 10 not clearing it', () {
      expect(chapterOf(900), 9);
      expect(chapterOf(901), 10);
      expect(
        unlocks(withLevels(0, currentLevel: 900), GameAchievement.halfwayDown),
        isFalse,
      );
      expect(
        unlocks(withLevels(0, currentLevel: 901), GameAchievement.halfwayDown),
        isTrue,
      );
    });

    test('Still Water is reaching chapter 20', () {
      expect(chapterOf(1901), kChapterCount);
      expect(
        unlocks(withLevels(0, currentLevel: 1900), GameAchievement.stillWater),
        isFalse,
      );
      expect(
        unlocks(withLevels(0, currentLevel: 1901), GameAchievement.stillWater),
        isTrue,
      );
    });
  });

  group('stars', () {
    test('First Light needs three stars on one level', () {
      expect(
        unlocks(withLevels(40, starsEach: 2), GameAchievement.firstLight),
        isFalse,
        reason: 'plenty of stars but never three on one level',
      );
      expect(
        unlocks(withLevels(1, starsEach: 3), GameAchievement.firstLight),
        isTrue,
      );
    });

    test('Constellation and Star Chart count stars held', () {
      final save = withLevels(50, starsEach: 3); // 150 stars
      expect(save.totalStars, 150);
      expect(stepsFor(save, GameAchievement.constellation), 100); // capped
      expect(stepsFor(save, GameAchievement.starChart), 150);
    });

    test('Perfectionist and Flawless Depths count three star levels', () {
      final save = withLevels(60, starsEach: 3);
      expect(save.threeStarCount, 60);
      expect(stepsFor(save, GameAchievement.perfectionist), 50); // capped
      expect(stepsFor(save, GameAchievement.flawlessDepths), 60);
    });

    test('two star levels do not count towards Perfectionist', () {
      final save = withLevels(60, starsEach: 2);
      expect(save.threeStarCount, 0);
      expect(stepsFor(save, GameAchievement.perfectionist), isNull);
    });
  });

  group('score', () {
    test('each tier needs its exact total', () {
      for (final (score, a) in <(int, GameAchievement)>[
        (10000, GameAchievement.tenThousand),
        (100000, GameAchievement.sixFigures),
        (1000000, GameAchievement.millionaire),
      ]) {
        expect(
          unlocks(SaveData(totalScore: score - 1), a),
          isFalse,
          reason: '${a.name} unlocked one point early',
        );
        expect(unlocks(SaveData(totalScore: score), a), isTrue);
      }
    });
  });

  group('Unaided', () {
    test('counts only completions where no booster was spent', () {
      expect(
        stepsFor(SaveData(unaidedCompletions: 0), GameAchievement.unaided),
        isNull,
      );
      expect(
        stepsFor(SaveData(unaidedCompletions: 7), GameAchievement.unaided),
        7,
      );
      expect(
        stepsFor(SaveData(unaidedCompletions: 99), GameAchievement.unaided),
        25,
        reason: 'capped at the target',
      );
    });

    test('recordResult only counts a first completion', () {
      final save = SaveData();
      save.recordResult(1, 3, 100, unaided: true);
      expect(save.unaidedCompletions, 1);
      // Replaying the same level must not inflate it.
      save.recordResult(1, 3, 100, unaided: true);
      expect(save.unaidedCompletions, 1);
      // A level beaten with a booster does not count at all.
      save.recordResult(2, 3, 100, unaided: false);
      expect(save.unaidedCompletions, 1);
      expect(save.levelsCompleted, 2);
    });
  });

  group('Chain Reaction', () {
    test('is never derived from the save', () {
      // It is a property of one placement, fired from the board. If it ever
      // appears here it means someone tried to infer it from progress, which
      // would unlock it for a player who never did it.
      final save = withLevels(kLevelCount, starsEach: 3);
      final progress = achievementProgress(save);
      expect(progress.unlock, isNot(contains(GameAchievement.chainReaction)));
      expect(progress.steps, isNot(contains(GameAchievement.chainReaction)));
    });
  });

  group('the catalogue as a whole', () {
    test('a fresh save earns nothing', () {
      expect(achievementProgress(SaveData()).isEmpty, isTrue);
    });

    test('a finished game earns every achievement bar Chain Reaction', () {
      final save = SaveData(
        currentLevel: kLevelCount,
        stars: <int, int>{for (var i = 1; i <= kLevelCount; i++) i: 3},
        totalScore: 1000000,
        levelsCompleted: kLevelCount,
        unaidedCompletions: kLevelCount,
      );
      final progress = achievementProgress(save);
      final covered = <GameAchievement>{
        ...progress.unlock,
        ...progress.steps.keys,
      };
      expect(
        GameAchievement.values.toSet().difference(covered),
        <GameAchievement>{GameAchievement.chainReaction},
      );
      // Every incremental one is at its target, so Play shows them complete.
      for (final entry in progress.steps.entries) {
        expect(entry.value, entry.key.steps, reason: entry.key.name);
      }
    });

    test('no step count is ever reported above its target', () {
      for (final n in <int>[1, 26, 101, 501, 1001, kLevelCount]) {
        final save = SaveData(
          currentLevel: kLevelCount,
          stars: <int, int>{for (var i = 1; i <= n; i++) i: 3},
          totalScore: 1000000,
          levelsCompleted: n,
          unaidedCompletions: n,
        );
        achievementProgress(save).steps.forEach((a, v) {
          expect(v, lessThanOrEqualTo(a.steps), reason: '${a.name} at n=$n');
          expect(v, greaterThan(0), reason: '${a.name} at n=$n');
        });
      }
    });

    test('only incremental achievements report steps', () {
      final save = withLevels(kLevelCount, starsEach: 3);
      for (final a in achievementProgress(save).steps.keys) {
        expect(a.isIncremental, isTrue, reason: a.name);
      }
    });
  });
}
