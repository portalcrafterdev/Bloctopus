/// Level model and chapter metadata.
///
/// Pure Dart. No Flutter imports: consumed by the generator and the solver.
library;

/// Appended to, never reordered: the index is what is written into the level
/// files.
enum GoalType {
  clearLines,
  reachScore,
  breakBlocks,
  clearJelly,
  survive,
  collectStars,
}

/// `preset` cell encoding, one int per cell, row major.
class PresetCell {
  static const int empty = 0;
  static const int blocked = 1;
  static const int filled = 2;
  static const int jelly = 3;
  static const int doubleJelly = 4;
  static const int stone = 5;

  /// An ordinary block with a star sitting on it. Collected when a line
  /// clears through it. Added after the first cut of section 6.2, which is
  /// why it is 6 rather than sitting with the other specials.
  static const int star = 6;
}

class Level {
  final int id; // 1..1500
  final int chapter; // 1..15
  final GoalType goal;
  final int target; // lines / score / blocks / jelly count / moves survived
  final int moveLimit; // 0 means unlimited
  final List<int> preset; // 64 ints, board start state
  final List<int> shapePool; // indices into the shape library
  final int seed; // deterministic piece sequence
  final List<int> starTargets; // [1 star, 2 star, 3 star] score thresholds

  /// 0..1, produced by the generator. Used only to sort the curve.
  final double difficulty;

  const Level({
    required this.id,
    required this.chapter,
    required this.goal,
    required this.target,
    required this.moveLimit,
    required this.preset,
    required this.shapePool,
    required this.seed,
    required this.starTargets,
    this.difficulty = 0,
  });

  /// Every 25th level is a boss.
  bool get isBoss => id % 25 == 0;

  /// The level that introduces this chapter's new element.
  bool get isChapterOpener => (id - 1) % 100 == 0;

  int get jellyCount => preset
      .where((c) => c == PresetCell.jelly || c == PresetCell.doubleJelly)
      .length;

  int get presetBlockCount =>
      preset.where((c) => c == PresetCell.filled).length;

  int get starCount => preset.where((c) => c == PresetCell.star).length;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'ch': chapter,
    'goal': goal.index,
    'target': target,
    'moves': moveLimit,
    'preset': _packPreset(preset),
    'pool': shapePool,
    'seed': seed,
    'stars': starTargets,
    'diff': double.parse(difficulty.toStringAsFixed(4)),
  };

  factory Level.fromJson(Map<String, dynamic> json) => Level(
    id: json['id'] as int,
    chapter: json['ch'] as int,
    goal: GoalType.values[json['goal'] as int],
    target: json['target'] as int,
    moveLimit: json['moves'] as int,
    preset: _unpackPreset(json['preset'] as String),
    shapePool: (json['pool'] as List).cast<int>(),
    seed: json['seed'] as int,
    starTargets: (json['stars'] as List).cast<int>(),
    difficulty: (json['diff'] as num?)?.toDouble() ?? 0,
  );
}

/// The preset is 64 digits 0..5. A string is a third the size of a JSON array
/// of ints and decodes faster, which matters for the 16ms load budget.
String _packPreset(List<int> preset) => preset.join();

List<int> _unpackPreset(String s) =>
    List<int>.generate(s.length, (i) => s.codeUnitAt(i) - 0x30);

class LevelResult {
  final bool won;
  final int stars; // 0..3
  final int score;
  final int movesUsed;
  final int linesCleared;

  /// Booster awarded by this result, if any. See section 8.
  final String? boosterAwarded;

  const LevelResult({
    required this.won,
    required this.stars,
    required this.score,
    required this.movesUsed,
    required this.linesCleared,
    this.boosterAwarded,
  });
}

class ChapterInfo {
  final int number;
  final String theme;
  final String newElement;
  final String? tutorial; // mascot copy, max 12 words

  const ChapterInfo(this.number, this.theme, this.newElement, this.tutorial);

  int get firstLevel => (number - 1) * 100 + 1;

  int get lastLevel => number * 100;

  /// `assets/levels/levels_001_100.json`
  String get assetPath {
    final a = firstLevel.toString().padLeft(3, '0');
    final b = lastLevel.toString().padLeft(3, '0');
    return 'assets/levels/levels_${a}_$b.json';
  }
}

const List<ChapterInfo> kChapters = <ChapterInfo>[
  ChapterInfo(
    1,
    'Tide Pools',
    'none',
    'Fill a full row or column to clear it.',
  ),
  ChapterInfo(
    2,
    'Kelp Forest',
    'stars and score goals',
    'Stars come off when a line clears through them.',
  ),
  ChapterInfo(
    3,
    'Coral Shelf',
    'move limit',
    'This depth counts your moves. Spend them well.',
  ),
  ChapterInfo(
    4,
    'Wreck Reef',
    'pre-filled blocks',
    'Old blocks break when a line passes through.',
  ),
  ChapterInfo(
    5,
    'Jelly Drift',
    'jelly',
    'Jelly clears when a line passes through it.',
  ),
  ChapterInfo(
    6,
    'Stone Trench',
    'blocked cells',
    'Dark cells never fill and never clear.',
  ),
  ChapterInfo(
    7,
    'Bloom Deep',
    'double jelly',
    'Thick jelly needs two lines through it.',
  ),
  ChapterInfo(
    8,
    'Cold Current',
    'restricted shape pool',
    'Fewer shapes down here. Plan further ahead.',
  ),
  ChapterInfo(
    9,
    'Basalt Maze',
    'stone',
    'Stone softens on the first line, clears on the second.',
  ),
  ChapterInfo(
    10,
    'Abyss',
    'survive goals',
    'Survive the set number of moves without getting stuck.',
  ),
  ChapterInfo(11, 'Ink Depths I', 'remix', null),
  ChapterInfo(12, 'Ink Depths II', 'remix', null),
  ChapterInfo(13, 'Ink Depths III', 'remix', null),
  ChapterInfo(14, 'Ink Depths IV', 'remix', null),
  ChapterInfo(15, 'Ink Depths V', 'remix', null),
];

const int kLevelCount = 1500;
const int kChapterCount = 15;

int chapterOf(int levelId) =>
    ((levelId - 1) ~/ 100 + 1).clamp(1, kChapterCount);

ChapterInfo chapterInfo(int chapter) =>
    kChapters[(chapter - 1).clamp(0, kChapterCount - 1)];

/// Human readable goal line for the HUD banner. Sentence case, no exclamation.
String goalText(Level level) {
  switch (level.goal) {
    case GoalType.clearLines:
      return 'Clear ${level.target} ${level.target == 1 ? 'line' : 'lines'}';
    case GoalType.reachScore:
      return 'Reach ${level.target} points';
    case GoalType.breakBlocks:
      return 'Break ${level.target} blocks';
    case GoalType.clearJelly:
      return 'Clear ${level.target} jelly';
    case GoalType.survive:
      return 'Survive ${level.target} moves';
    case GoalType.collectStars:
      return 'Collect ${level.target} ${level.target == 1 ? 'star' : 'stars'}';
  }
}
