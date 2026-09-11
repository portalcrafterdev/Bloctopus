import '../models/level.dart';
import '../models/save_data.dart';
import 'games_ids.dart';

/// What the save currently entitles the player to.
///
/// [unlock] holds the standard achievements whose condition is met.
/// [steps] holds the running total for each incremental one, which Play draws
/// as a progress bar. Both are absolute rather than deltas: `setSteps` never
/// reduces existing progress and unlocking twice is harmless, so sending the
/// whole picture on every level completion is safe and means a player who was
/// signed out when they earned something still gets it next time they play.
class AchievementProgress {
  final Set<GameAchievement> unlock;
  final Map<GameAchievement, int> steps;

  const AchievementProgress({required this.unlock, required this.steps});

  bool get isEmpty => unlock.isEmpty && steps.isEmpty;
}

/// The incremental achievement the player is closest to finishing, with how
/// far along it is.
///
/// Drives the home screen's one achievement row. Incremental only: a standard
/// achievement is all or nothing, so "closest" means nothing for it. Returns
/// null when every incremental one is already at its target, which is the
/// honest empty state - a row claiming progress on a finished goal would be
/// worse than no row.
({GameAchievement achievement, int value})? nearestAchievement(SaveData save) {
  ({GameAchievement achievement, int value})? best;
  var bestRatio = -1.0;
  achievementProgress(save).steps.forEach((a, value) {
    if (value >= a.steps) return;
    final ratio = value / a.steps;
    if (ratio > bestRatio) {
      bestRatio = ratio;
      best = (achievement: a, value: value);
    }
  });
  return best;
}

/// Reads the save and decides what has been earned.
///
/// Pure on purpose, so every threshold can be tested on both sides of its
/// boundary without a platform channel. The wording in each comment is the
/// achievement's description in Play Console, copied exactly - if the two ever
/// disagree, the console is what the player was promised and this is the bug.
AchievementProgress achievementProgress(SaveData save) {
  final unlock = <GameAchievement>{};
  final steps = <GameAchievement, int>{};

  /// Incremental achievements all report an absolute count, capped at their
  /// target: Play rejects a step count above the configured maximum.
  void progress(GameAchievement a, int value) {
    if (value > 0) steps[a] = value.clamp(0, a.steps);
  }

  final completed = save.levelsCompleted;
  final stars = save.totalStars;
  final threeStars = save.threeStarCount;

  // -- levels completed ----------------------------------------------------
  // "Complete your first level."
  if (completed >= 1) unlock.add(GameAchievement.firstRipple);
  // "Complete 10 / 50 / 100 / 250 / 500 / 1000 levels."
  progress(GameAchievement.tideWalker, completed);
  progress(GameAchievement.reefRunner, completed);
  progress(GameAchievement.deepDiver, completed);
  progress(GameAchievement.trenchCrawler, completed);
  progress(GameAchievement.abyssDweller, completed);
  progress(GameAchievement.inkSovereign, completed);

  // -- chapters ------------------------------------------------------------
  // "Complete every level in Tide Pools." Every level of chapter 1, not just
  // reaching the end of it.
  if (save.isChapterComplete(1)) {
    unlock.add(GameAchievement.tidePoolsCleared);
  }
  // "Reach the Abyss in chapter 10." Reaching, so the moment chapter 10
  // unlocks, which is currentLevel rather than anything completed.
  if (chapterOf(save.currentLevel) >= 10) {
    unlock.add(GameAchievement.halfwayDown);
  }
  // "Reach Still Water in chapter 20."
  if (chapterOf(save.currentLevel) >= kChapterCount) {
    unlock.add(GameAchievement.stillWater);
  }

  // -- stars ---------------------------------------------------------------
  // "Earn three stars on any level."
  if (threeStars >= 1) unlock.add(GameAchievement.firstLight);
  // "Earn 100 / 500 stars." Stars held, so a level re-beaten better counts
  // once at its best rather than twice.
  progress(GameAchievement.constellation, stars);
  progress(GameAchievement.starChart, stars);
  // "Earn three stars on 50 / 200 levels."
  progress(GameAchievement.perfectionist, threeStars);
  progress(GameAchievement.flawlessDepths, threeStars);

  // -- score ---------------------------------------------------------------
  // "Reach a total score of 10000 / 100000 / 1000000."
  if (save.totalScore >= 10000) unlock.add(GameAchievement.tenThousand);
  if (save.totalScore >= 100000) unlock.add(GameAchievement.sixFigures);
  if (save.totalScore >= 1000000) unlock.add(GameAchievement.millionaire);

  // -- how you played ------------------------------------------------------
  // "Complete 25 levels without using a booster."
  progress(GameAchievement.unaided, save.unaidedCompletions);

  // Chain Reaction - "Clear three lines with a single piece" - is not here.
  // It is not a property of the save at all: it happens inside one placement
  // and is fired from the board as it happens.

  return AchievementProgress(unlock: unlock, steps: steps);
}
