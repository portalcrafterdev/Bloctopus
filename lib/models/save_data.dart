import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'level.dart';

const String kSaveKey = 'blocktopus_save_v1';
const int kSaveVersion = 1;

/// Booster ids. Kept as plain strings because they are persisted.
class BoosterId {
  static const String undo = 'undo';
  static const String hammer = 'hammer';
  static const String refresh = 'refresh';

  static const List<String> all = <String>[undo, hammer, refresh];

  /// In-game names, section 8.
  static String label(String id) => switch (id) {
    undo => 'Rewind',
    hammer => 'Ink blast',
    refresh => 'Reshuffle',
    _ => id,
  };
}

class GameSettings {
  bool sfx;
  bool music;
  bool haptics;
  bool reduceMotion;

  /// 0..1, applied on top of the per-sound volumes. The toggles above stay:
  /// a slider at zero and a switch off are different intents, and a player who
  /// silenced music should not have to remember where they left the slider.
  double sfxVolume;
  double musicVolume;

  /// The music bed is ambient and has no percussion, so it needs to sit high
  /// enough to be noticed at all. It ducks to 40% whenever an effect plays.
  static const double defaultMusicVolume = 0.8;
  static const double defaultSfxVolume = 1;

  GameSettings({
    this.sfx = true,
    this.music = true,
    this.haptics = true,
    this.reduceMotion = false,
    this.sfxVolume = defaultSfxVolume,
    this.musicVolume = defaultMusicVolume,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sfx': sfx,
    'music': music,
    'haptics': haptics,
    'reduceMotion': reduceMotion,
    'sfxVolume': sfxVolume,
    'musicVolume': musicVolume,
  };

  /// Absent keys take the defaults, so a save written before the sliders
  /// existed loads without a version bump or a migration step.
  factory GameSettings.fromJson(Map<String, dynamic> j) => GameSettings(
    sfx: j['sfx'] as bool? ?? true,
    music: j['music'] as bool? ?? true,
    haptics: j['haptics'] as bool? ?? true,
    reduceMotion: j['reduceMotion'] as bool? ?? false,
    sfxVolume: _level(j['sfxVolume'], defaultSfxVolume),
    musicVolume: _level(j['musicVolume'], defaultMusicVolume),
  );

  /// Type tested rather than cast. A cast throws on a value of the wrong type,
  /// and the only handler for that is the catch in `SaveData.load`, which
  /// discards the entire blob: one bad settings key would silently reset a
  /// player's progress.
  static double _level(Object? raw, double fallback) {
    if (raw is! num) return fallback;
    final v = raw.toDouble();
    if (v.isNaN) return fallback;
    return v.clamp(0.0, 1.0);
  }
}

/// The single persisted blob, section 12. Written on level completion and on
/// settings changes, never per frame.
class SaveData extends ChangeNotifier {
  int version;
  int currentLevel;
  final Map<int, int> stars;
  final Map<String, int> boosters;
  GameSettings settings;
  int totalScore;
  int levelsCompleted;

  /// Levels beaten on their first completion without spending a booster.
  ///
  /// Counted on first completion only, so a level cannot be replayed to farm
  /// it, which matches the achievement's wording of "25 levels" rather than
  /// 25 wins. Absent from older saves and read as zero, so no version bump.
  int unaidedCompletions;

  SaveData({
    this.version = kSaveVersion,
    this.currentLevel = 1,
    Map<int, int>? stars,
    Map<String, int>? boosters,
    GameSettings? settings,
    this.totalScore = 0,
    this.levelsCompleted = 0,
    this.unaidedCompletions = 0,
  }) : stars = stars ?? <int, int>{},
       boosters =
           boosters ??
           <String, int>{
             BoosterId.undo: 3,
             BoosterId.hammer: 3,
             BoosterId.refresh: 3,
           },
       settings = settings ?? GameSettings();

  SharedPreferences? _prefs;

  static Future<SaveData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSaveKey);
    SaveData data;
    if (raw == null) {
      data = SaveData();
    } else {
      try {
        data = SaveData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // A corrupt blob must never brick the app. Start fresh.
        data = SaveData();
      }
    }
    data._prefs = prefs;
    return data;
  }

  factory SaveData.fromJson(Map<String, dynamic> j) {
    final rawStars = (j['stars'] as Map?) ?? const <String, dynamic>{};
    final rawBoosters = (j['boosters'] as Map?) ?? const <String, dynamic>{};
    return SaveData(
      version: j['version'] as int? ?? kSaveVersion,
      currentLevel: (j['currentLevel'] as int? ?? 1).clamp(1, kLevelCount),
      stars: <int, int>{
        for (final e in rawStars.entries)
          if (int.tryParse(e.key.toString()) != null)
            int.parse(e.key.toString()): (e.value as num).toInt(),
      },
      boosters: <String, int>{
        for (final id in BoosterId.all)
          id: (rawBoosters[id] as num?)?.toInt() ?? 3,
      },
      settings: GameSettings.fromJson(
        ((j['settings'] as Map?) ?? const <String, dynamic>{})
            .cast<String, dynamic>(),
      ),
      totalScore: j['totalScore'] as int? ?? 0,
      levelsCompleted: j['levelsCompleted'] as int? ?? 0,
      unaidedCompletions: j['unaidedCompletions'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'currentLevel': currentLevel,
    'stars': <String, int>{
      for (final e in stars.entries) e.key.toString(): e.value,
    },
    'boosters': boosters,
    'settings': settings.toJson(),
    'totalScore': totalScore,
    'levelsCompleted': levelsCompleted,
    'unaidedCompletions': unaidedCompletions,
  };

  Future<void> save() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(kSaveKey, jsonEncode(toJson()));
  }

  // -- progression ----------------------------------------------------------

  int starsFor(int levelId) => stars[levelId] ?? 0;

  /// Stars earned across every level. Shown on the home, map and settings
  /// screens, and submitted to the stars leaderboard.
  int get totalStars => stars.values.fold<int>(0, (a, b) => a + b);

  /// Levels beaten at three stars. Feeds the Perfectionist and Flawless
  /// Depths achievements.
  int get threeStarCount => stars.values.where((s) => s == 3).length;

  /// Whether every level in [chapter] has been completed.
  bool isChapterComplete(int chapter) {
    final first = (chapter - 1) * 100 + 1;
    for (var id = first; id < first + 100 && id <= kLevelCount; id++) {
      if (!isCompleted(id)) return false;
    }
    return true;
  }

  /// Linear unlock. Level N+1 unlocks when N is completed. No star gates.
  bool isUnlocked(int levelId) => levelId <= currentLevel;

  bool isCompleted(int levelId) => (stars[levelId] ?? 0) > 0;

  int get highestUnlocked => currentLevel;

  int boosterCount(String id) => boosters[id] ?? 0;

  bool hasBooster(String id) => boosterCount(id) > 0;

  /// Spends one booster. Returns false when there are none left, which is
  /// where a "watch an ad to earn one" hook would go later.
  bool spendBooster(String id) {
    final n = boosterCount(id);
    if (n <= 0) return false;
    boosters[id] = n - 1;
    notifyListeners();
    save();
    return true;
  }

  void awardBooster(String id, [int n = 1]) {
    boosters[id] = boosterCount(id) + n;
    notifyListeners();
    save();
  }

  /// Tops [id] back up to [floor] if it has fallen below it. Returns true when
  /// it actually granted something.
  ///
  /// Section 8 starts the player with three of each and refills only on a
  /// three star clear or a boss level. That strands anyone who spends them:
  /// the booster you need is the one you cannot earn without it. A floor is
  /// the smallest fix that does not touch the rest of the economy - a player
  /// who has saved more than the floor keeps all of it.
  bool ensureBooster(String id, int floor) {
    if (boosterCount(id) >= floor) return false;
    boosters[id] = floor;
    notifyListeners();
    save();
    return true;
  }

  /// Records a finished level and returns the booster awarded, if any.
  ///
  /// [unaided] means no booster was spent on this attempt. It only counts on
  /// a first completion, alongside [levelsCompleted], so replaying a level
  /// cannot inflate it.
  String? recordResult(
    int levelId,
    int stars,
    int score, {
    bool unaided = false,
  }) {
    final previous = starsFor(levelId);
    if (stars > previous) this.stars[levelId] = stars;
    if (stars > 0) {
      totalScore += score;
      if (previous == 0) {
        levelsCompleted++;
        if (unaided) unaidedCompletions++;
      }
      if (levelId + 1 > currentLevel && levelId < kLevelCount) {
        currentLevel = levelId + 1;
      }
    }

    String? awarded;
    // +1 random booster on every 3 star clear and on every boss level.
    final boss = levelId % 25 == 0;
    if (stars > 0 && (stars == 3 || boss) && previous < 3) {
      awarded = BoosterId.all[(levelId * 7 + stars) % BoosterId.all.length];
      boosters[awarded] = boosterCount(awarded) + 1;
    }

    notifyListeners();
    save();
    return awarded;
  }

  void updateSettings(void Function(GameSettings s) change) {
    change(settings);
    notifyListeners();
    save();
  }

  /// Used by the settings screen. Wipes progress but keeps nothing hidden.
  Future<void> resetProgress() async {
    currentLevel = 1;
    stars.clear();
    totalScore = 0;
    levelsCompleted = 0;
    for (final id in BoosterId.all) {
      boosters[id] = 3;
    }
    notifyListeners();
    await save();
  }
}
