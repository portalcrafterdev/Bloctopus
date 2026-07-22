/// Offline level generator. Never shipped, never runs on device.
///
///   dart run tool/generate_levels.dart                  # all 15 chapters
///   dart run tool/generate_levels.dart --chapters=1     # one chapter
///   dart run tool/generate_levels.dart --candidates=30000
///   dart run tool/generate_levels.dart --isolates=8
///
/// See section 6.4. Every emitted level has been solved by the solver, has
/// defeated the greedy baseline player, and carries a measured difficulty.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:blocktopus/game/board_state.dart';
import 'package:blocktopus/game/solver.dart';
import 'package:blocktopus/models/level.dart';
import 'package:blocktopus/models/piece.dart';

const int kLevelsPerChapter = 100;

// ---------------------------------------------------------------------------
// Shape pools
// ---------------------------------------------------------------------------

/// Gentle shapes. Nothing above five cells, no diagonals.
///
/// T, S and Z are in here even though they make packing harder. They are what
/// anyone opening a block puzzle expects to see in the tray, and holding them
/// back until chapter 3 made the first two hundred levels feel like a
/// different, smaller game. What keeps chapter 1 gentle is its density, its
/// unlimited moves and the difficulty sort, not a short shape list.
///
/// Diagonals stay out: those are genuinely awkward and are the one thing worth
/// introducing later.
const List<int> kPoolBasic = <int>[
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  9,
  13,
  14,
  15,
  16,
  25,
  26,
  27,
  28,
  21,
  22,
  23,
  24,
  29,
  30,
  31,
  32,
  33,
  34,
  35,
  36,
];

/// Adds T, S, Z and the longer bars.
const List<int> kPoolStandard = <int>[
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  11,
  12,
  13,
  14,
  15,
  16,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
  31,
  32,
  33,
  34,
  35,
  36,
];

/// Everything, including 3x3 blocks, big corners and diagonals.
const List<int> kPoolFull = <int>[
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
  31,
  32,
  33,
  34,
  35,
  36,
  37,
  38,
  39,
  40,
];

/// Awkward shapes that punish sloppy packing. Chapter 8 draws from these.
const List<int> kPoolAwkward = <int>[
  7,
  8,
  10,
  17,
  18,
  19,
  20,
  29,
  30,
  31,
  32,
  33,
  34,
  35,
  36,
  39,
  40,
];

// ---------------------------------------------------------------------------
// Chapter parameters
// ---------------------------------------------------------------------------

class ChapterParams {
  final int chapter;
  final List<GoalType> goals;
  final double densityMin;
  final double densityMax;

  /// Move budget the generator validates against. For chapters that ship with
  /// `moveLimit: 0` this is a par, not a cap: the player is not limited, but
  /// the level must still be beatable inside it and must defeat greedy inside
  /// it. Without a par, "greedy fails" is meaningless on an unlimited level.
  final int parMin;
  final int parMax;

  /// True when the shipped level carries the par as a hard move limit.
  final bool enforceMoveLimit;

  final List<int> pool;

  /// If set, each level draws a random subset of this size from [pool].
  final int? restrictPoolTo;

  final int blockedMin;
  final int blockedMax;
  final int jellyMin;
  final int jellyMax;
  final int doubleJellyMin;
  final int doubleJellyMax;
  final int stoneMin;
  final int stoneMax;
  final int starMin;
  final int starMax;

  const ChapterParams({
    required this.chapter,
    required this.goals,
    required this.densityMin,
    required this.densityMax,
    required this.parMin,
    required this.parMax,
    required this.enforceMoveLimit,
    required this.pool,
    this.restrictPoolTo,
    this.blockedMin = 0,
    this.blockedMax = 0,
    this.jellyMin = 0,
    this.jellyMax = 0,
    this.doubleJellyMin = 0,
    this.doubleJellyMax = 0,
    this.stoneMin = 0,
    this.stoneMax = 0,
    this.starMin = 0,
    this.starMax = 0,
  });
}

/// Section 6.3. Exactly one new element per chapter.
///
/// Note on chapters 1-3: section 6.4 requires the starting board to be "not
/// fully empty", while pre-filled blocks are listed as chapter 4's new
/// element. These are reconciled by scattering a few ordinary blocks in the
/// early chapters - visually they are just blocks, identical to placed ones -
/// and letting chapter 4 introduce the *breakBlocks goal* and the heavier
/// densities that go with it.
final Map<int, ChapterParams> kChapterParams = <int, ChapterParams>{
  // Chapters 1 and 2 used to run a hundred levels each on a single goal, an
  // empty-ish board and no move limit. That is two hundred levels before the
  // game shows the player anything it has not already shown them, and it read
  // as monotonous long before the first mechanic arrived.
  //
  // The list below is weighted by repetition: `goals[rnd.nextInt(len)]`, so
  // three entries of one goal to one of another is roughly a 3:1 split. The
  // chapter still has a clear identity, it just is not the only thing in it.
  1: const ChapterParams(
    chapter: 1,
    goals: <GoalType>[
      GoalType.clearLines,
      GoalType.clearLines,
      GoalType.clearLines,
      GoalType.collectStars,
    ],
    densityMin: 0.08,
    densityMax: 0.20,
    parMin: 9,
    parMax: 13,
    enforceMoveLimit: false,
    pool: kPoolBasic,
    starMin: 2,
    starMax: 5,
  ),
  2: const ChapterParams(
    chapter: 2,
    goals: <GoalType>[
      GoalType.reachScore,
      GoalType.reachScore,
      GoalType.collectStars,
      GoalType.clearLines,
    ],
    densityMin: 0.09,
    densityMax: 0.23,
    parMin: 10,
    parMax: 15,
    enforceMoveLimit: false,
    pool: kPoolBasic,
    starMin: 3,
    starMax: 7,
  ),
  3: const ChapterParams(
    chapter: 3,
    goals: <GoalType>[GoalType.clearLines],
    densityMin: 0.08,
    densityMax: 0.22,
    parMin: 9,
    parMax: 14,
    enforceMoveLimit: true,
    pool: kPoolStandard,
  ),
  4: const ChapterParams(
    chapter: 4,
    goals: <GoalType>[GoalType.breakBlocks],
    densityMin: 0.16,
    densityMax: 0.32,
    parMin: 10,
    parMax: 16,
    enforceMoveLimit: true,
    pool: kPoolStandard,
  ),
  5: const ChapterParams(
    chapter: 5,
    goals: <GoalType>[GoalType.clearJelly],
    densityMin: 0.12,
    densityMax: 0.28,
    parMin: 11,
    parMax: 17,
    enforceMoveLimit: true,
    pool: kPoolStandard,
    jellyMin: 4,
    jellyMax: 9,
  ),
  6: const ChapterParams(
    chapter: 6,
    goals: <GoalType>[
      GoalType.clearLines,
      GoalType.reachScore,
      GoalType.breakBlocks,
      GoalType.collectStars,
    ],
    densityMin: 0.14,
    densityMax: 0.30,
    parMin: 11,
    parMax: 17,
    enforceMoveLimit: true,
    pool: kPoolStandard,
    starMin: 4,
    starMax: 8,
    blockedMin: 2,
    blockedMax: 6,
  ),
  7: const ChapterParams(
    chapter: 7,
    goals: <GoalType>[GoalType.clearJelly],
    densityMin: 0.14,
    densityMax: 0.30,
    parMin: 12,
    parMax: 18,
    enforceMoveLimit: true,
    pool: kPoolStandard,
    jellyMin: 2,
    jellyMax: 5,
    doubleJellyMin: 3,
    doubleJellyMax: 7,
    blockedMin: 0,
    blockedMax: 4,
  ),
  8: const ChapterParams(
    chapter: 8,
    goals: <GoalType>[GoalType.reachScore],
    densityMin: 0.12,
    densityMax: 0.28,
    parMin: 9,
    parMax: 13,
    enforceMoveLimit: true,
    pool: kPoolAwkward,
    restrictPoolTo: 6,
    blockedMin: 0,
    blockedMax: 4,
  ),
  9: const ChapterParams(
    chapter: 9,
    goals: <GoalType>[
      GoalType.clearLines,
      GoalType.breakBlocks,
      GoalType.clearJelly,
    ],
    densityMin: 0.16,
    densityMax: 0.32,
    parMin: 12,
    parMax: 18,
    enforceMoveLimit: true,
    pool: kPoolFull,
    stoneMin: 3,
    stoneMax: 8,
    blockedMin: 0,
    blockedMax: 5,
    jellyMin: 0,
    jellyMax: 4,
  ),
  10: const ChapterParams(
    chapter: 10,
    goals: <GoalType>[GoalType.survive],
    densityMin: 0.14,
    densityMax: 0.30,
    parMin: 16,
    parMax: 26,
    enforceMoveLimit: true,
    pool: kPoolFull,
    blockedMin: 0,
    blockedMax: 6,
  ),
};

/// Chapters 11-15 remix everything, with rising density and tighter pars.
ChapterParams paramsFor(int chapter) {
  final known = kChapterParams[chapter];
  if (known != null) return known;
  final t = (chapter - 11) / 4.0; // 0..1 across Ink Depths I-V
  return ChapterParams(
    chapter: chapter,
    goals: const <GoalType>[
      GoalType.clearLines,
      GoalType.reachScore,
      GoalType.breakBlocks,
      GoalType.clearJelly,
      GoalType.survive,
      GoalType.collectStars,
    ],
    densityMin: 0.18 + 0.06 * t,
    densityMax: 0.32 + 0.10 * t,
    parMin: (13 - 2 * t).round(),
    parMax: (19 - 3 * t).round(),
    enforceMoveLimit: true,
    pool: kPoolFull,
    blockedMin: 2,
    blockedMax: (5 + 4 * t).round(),
    jellyMin: 2,
    jellyMax: (6 + 3 * t).round(),
    doubleJellyMin: 1,
    doubleJellyMax: (4 + 3 * t).round(),
    stoneMin: 1,
    stoneMax: (4 + 3 * t).round(),
    // Deeper boards are fuller, so a star can hide behind more of them.
    starMin: 4,
    starMax: (7 + 3 * t).round(),
  );
}

// ---------------------------------------------------------------------------
// Candidate generation
// ---------------------------------------------------------------------------

/// One accepted candidate, in a form an isolate can send home.
class Candidate {
  final Level level;
  final double difficulty;

  /// Length of the solution the solver actually found. An upper bound on the
  /// true minimum, which is what boss tightening is allowed to rely on.
  final int solutionMoves;

  /// Score of that solution. Star thresholds are derived from it.
  final int solutionScore;

  const Candidate(
    this.level,
    this.difficulty,
    this.solutionMoves,
    this.solutionScore,
  );

  Map<String, dynamic> toWire() => <String, dynamic>{
    'l': level.toJson(),
    'd': difficulty,
    'm': solutionMoves,
    's': solutionScore,
  };

  static Candidate fromWire(Map<String, dynamic> m) => Candidate(
    Level.fromJson((m['l'] as Map).cast<String, dynamic>()),
    (m['d'] as num).toDouble(),
    m['m'] as int,
    m['s'] as int,
  );
}

/// Builds one random candidate for a chapter. Returns null when the random
/// preset is degenerate; the caller simply tries the next seed.
Level? buildCandidate(ChapterParams p, int seed) {
  final rnd = Random(seed);

  // The goal is drawn before the board, not after, because one of them decides
  // what goes on it. A star on a level that is not asking for stars is a
  // decorated block and nothing else, which is worse than no star at all.
  final goal = p.goals[rnd.nextInt(p.goals.length)];

  final density =
      p.densityMin + rnd.nextDouble() * (p.densityMax - p.densityMin);
  final fillCount = (density * kCellCount).round();
  if (fillCount == 0) return null;
  if (fillCount > kCellCount * 0.45) return null;

  final preset = List<int>.filled(kCellCount, PresetCell.empty);
  final cells = List<int>.generate(kCellCount, (i) => i)..shuffle(rnd);

  var cursor = 0;
  int take() => cells[cursor++];

  int span(int lo, int hi) => lo + (hi > lo ? rnd.nextInt(hi - lo + 1) : 0);

  final blocked = span(p.blockedMin, p.blockedMax);
  final jelly = span(p.jellyMin, p.jellyMax);
  final dJelly = span(p.doubleJellyMin, p.doubleJellyMax);
  final stone = span(p.stoneMin, p.stoneMax);
  final star = goal == GoalType.collectStars ? span(p.starMin, p.starMax) : 0;
  final specials = blocked + jelly + dJelly + stone + star;
  if (specials > fillCount) return null;

  for (var i = 0; i < blocked; i++) {
    preset[take()] = PresetCell.blocked;
  }
  for (var i = 0; i < jelly; i++) {
    preset[take()] = PresetCell.jelly;
  }
  for (var i = 0; i < dJelly; i++) {
    preset[take()] = PresetCell.doubleJelly;
  }
  for (var i = 0; i < stone; i++) {
    preset[take()] = PresetCell.stone;
  }
  for (var i = 0; i < star; i++) {
    preset[take()] = PresetCell.star;
  }
  for (var i = specials; i < fillCount; i++) {
    preset[take()] = PresetCell.filled;
  }

  // A preset must not start with a line already complete: it would sit there
  // looking wrong until something touched it.
  for (var y = 0; y < kBoardSize; y++) {
    var full = true;
    for (var x = 0; x < kBoardSize; x++) {
      if (preset[y * kBoardSize + x] == PresetCell.empty) {
        full = false;
        break;
      }
    }
    if (full) return null;
  }
  for (var x = 0; x < kBoardSize; x++) {
    var full = true;
    for (var y = 0; y < kBoardSize; y++) {
      if (preset[y * kBoardSize + x] == PresetCell.empty) {
        full = false;
        break;
      }
    }
    if (full) return null;
  }

  // Shape pool.
  var pool = p.pool;
  if (p.restrictPoolTo != null && p.restrictPoolTo! < pool.length) {
    final shuffled = List<int>.of(pool)..shuffle(rnd);
    pool = shuffled.take(p.restrictPoolTo!).toList()..sort();
    // Always keep at least one small shape, otherwise late boards deadlock on
    // a single empty cell and the level is unfair rather than hard.
    if (!pool.any((s) => kShapes[s].size <= 2)) {
      pool[0] = rnd.nextBool() ? 0 : 1;
      pool.sort();
    }
  }

  final par = span(p.parMin, p.parMax);
  final pieceSeed = 1 + rnd.nextInt(0x3FFFFFFF);

  final target = _pickTarget(goal, par, preset, rnd);
  if (target <= 0) return null;

  return Level(
    id: 0, // assigned during curation
    chapter: p.chapter,
    goal: goal,
    target: target,
    moveLimit: p.enforceMoveLimit ? par : 0,
    preset: preset,
    shapePool: pool,
    seed: pieceSeed,
    starTargets: const <int>[0, 0, 0], // filled in after solving
  );
}

int _pickTarget(GoalType goal, int par, List<int> preset, Random rnd) {
  switch (goal) {
    case GoalType.clearLines:
      // Roughly one line every two or three moves for a strong player.
      final lo = (par / 3.2).ceil().clamp(2, 12);
      final hi = (par / 2.0).ceil().clamp(lo, 14);
      return lo + rnd.nextInt(hi - lo + 1);
    case GoalType.reachScore:
      // A strong run scores roughly 11 to 16 a move: about 4.5 for the cells
      // placed, the rest from line bonuses. Targets above that are unreachable
      // inside par and every candidate gets rejected.
      final base = par * 11;
      return base + rnd.nextInt(par * 5);
    case GoalType.breakBlocks:
      final available = preset.where((c) => c == PresetCell.filled).length;
      if (available < 4) return 0;
      final lo = (available * 0.35).ceil();
      final hi = (available * 0.75).ceil();
      return hi <= lo ? lo : lo + rnd.nextInt(hi - lo + 1);
    case GoalType.clearJelly:
      final available = preset
          .where((c) => c == PresetCell.jelly || c == PresetCell.doubleJelly)
          .length;
      if (available < 3) return 0;
      final lo = (available * 0.5).ceil();
      return lo + rnd.nextInt((available - lo).clamp(0, 4) + 1);
    case GoalType.survive:
      return par;
    case GoalType.collectStars:
      final available = preset.where((c) => c == PresetCell.star).length;
      if (available < 2) return 0;
      // Most of them, but rarely all: needing the last star in the worst
      // corner turns a collection level into a puzzle with one solution.
      final lo = (available * 0.6).ceil();
      final hi = available <= 3 ? available : available - 1;
      return hi <= lo ? lo : lo + rnd.nextInt(hi - lo + 1);
  }
}

/// Runs the full acceptance test from section 6.4 step 5.
Candidate? evaluate(
  Level level,
  ChapterParams p, {
  required int nodeBudget,
  required int difficultyBudget,
  required int easyBudget,
}) {
  final par = level.moveLimit > 0 ? level.moveLimit : _parOf(level, p);

  // Cheap rejects first.
  final board = BoardState.fromPreset(level.preset, level.seed);
  if (board.filledCount == 0) return null;
  if (board.density > 0.45) return null;

  // 1. Solvable inside par.
  final solver = Solver(level, nodeBudget: nodeBudget);
  final solved = solver.solve(limit: par);
  if (!solved.solved) return null;

  // 2. Not trivially easy: no solution in fewer than par * 0.55 moves.
  //
  // This one gets its own, smaller budget. It is the only check that normally
  // *fails*, so it spends its whole budget every time and otherwise dominates
  // the run. It was never a proof either way: at six or seven moves deep the
  // real tree is many orders of magnitude past any budget we would give it,
  // so this is a filter for short solutions that are easy to find, which is
  // exactly the kind a player would stumble into.
  final easyDepth = (par * 0.55).ceil() - 1;
  if (easyDepth >= 1) {
    final easy = Solver(level, nodeBudget: easyBudget).solve(limit: easyDepth);
    if (easy.solved) return null;
  }

  // 3. The greedy baseline must fail it.
  final greedy = Solver(level, nodeBudget: nodeBudget);
  if (greedy.greedySolvesWithin(par)) return null;

  // 4. Difficulty, measured against the efficient solution rather than par.
  final diff = Solver(
    level,
    nodeBudget: nodeBudget,
  ).difficulty(perMoveBudget: difficultyBudget, limit: solved.moves);

  // Replay the found solution to learn what a strong run scores.
  final replay = BoardState.fromPreset(level.preset, level.seed);
  for (final m in solved.solution) {
    replay.place(m.shape, m.bx, m.by, m.colorIndex);
  }

  return Candidate(level, diff, solved.moves, replay.score);
}

int _parOf(Level level, ChapterParams p) =>
    level.moveLimit > 0 ? level.moveLimit : ((p.parMin + p.parMax) / 2).round();

// ---------------------------------------------------------------------------
// Curation
// ---------------------------------------------------------------------------

/// Assigns level ids so difficulty rises across the chapter, with every tenth
/// level 20% easier than its neighbours, and tightens boss levels.
List<Level> curate(int chapter, List<Candidate> pool) {
  if (pool.length < kLevelsPerChapter) {
    throw StateError(
      'chapter $chapter: only ${pool.length} candidates passed, '
      'need $kLevelsPerChapter. Raise --candidates.',
    );
  }

  final sorted = List<Candidate>.of(pool)
    ..sort((a, b) => a.difficulty.compareTo(b.difficulty));

  // Boss slots are picked before anything else, and picked for slack.
  //
  // A boss is supposed to carry a tighter move limit, but the limit can never
  // go below a solution we have actually proved exists. Two things follow.
  //
  // First, "tighter" has to mean tighter than the chapter, not tighter than
  // the candidate's own par. Each candidate draws its par independently, so a
  // candidate that happened to draw a high one still sits above the chapter
  // average after a 15% cut, and reads as a breather rather than a boss.
  //
  // Second, only candidates whose proved solution fits under that ceiling can
  // be tightened to it at all, so the ceiling is what selects them.
  final bossSlots = <int>[for (var i = 24; i < kLevelsPerChapter; i += 25) i];
  final ceiling = _bossCeiling(sorted);
  // The upper half by difficulty: a boss should not be a breather.
  final upperHalf = sorted.sublist(sorted.length ~/ 2);
  var slackEnough = upperHalf
      .where((c) => c.level.moveLimit == 0 || c.solutionMoves <= ceiling)
      .toList();
  if (slackEnough.length < bossSlots.length) {
    // Nothing in the upper half can be tightened that far. Fall back to the
    // hardest candidates that can, so bosses stay hard even if the whole
    // chapter's pars ran tight.
    slackEnough =
        (List<Candidate>.of(sorted)
              ..sort((a, b) => a.solutionMoves.compareTo(b.solutionMoves)))
            .take(bossSlots.length * 4)
            .toList()
          ..sort((a, b) => a.difficulty.compareTo(b.difficulty));
  }
  final bosses = <Candidate>[];
  if (slackEnough.length >= bossSlots.length) {
    final span = slackEnough.length - 1;
    for (var i = 0; i < bossSlots.length; i++) {
      final idx = (span * (i + 1) / bossSlots.length).round();
      bosses.add(slackEnough[idx.clamp(0, slackEnough.length - 1)]);
    }
  }

  final reserved = bosses.toSet();
  final rest = sorted.where((c) => !reserved.contains(c)).toList();
  final normalSlots = kLevelsPerChapter - bosses.length;

  // Trim to an even spread so a chapter is not built entirely out of
  // near-identical candidates.
  final chosen = <Candidate>[];
  for (var i = 0; i < normalSlots; i++) {
    final idx = (i * (rest.length - 1) / (normalSlots - 1)).round();
    chosen.add(rest[idx]);
  }

  final dMin = chosen.first.difficulty;
  final dMax = chosen.last.difficulty;

  // Desired difficulty per slot: a rising ramp, dipped 20% every tenth level.
  final desired = List<double>.generate(kLevelsPerChapter, (i) {
    var d = dMin + (dMax - dMin) * (i / (kLevelsPerChapter - 1));
    if ((i + 1) % 10 == 0) d *= 0.8;
    return d;
  });

  // Rank the non boss slots by desired difficulty, then hand the k-th easiest
  // candidate to the k-th easiest slot. Monotone, so the dips land where they
  // should. Boss slots were reserved above and sit outside this ordering.
  final slots =
      List<int>.generate(
          kLevelsPerChapter,
          (i) => i,
        ).where((i) => !bossSlots.contains(i) || bosses.isEmpty).toList()
        ..sort((a, b) => desired[a].compareTo(desired[b]));

  final assigned = List<Candidate?>.filled(kLevelsPerChapter, null);
  for (var k = 0; k < slots.length && k < chosen.length; k++) {
    assigned[slots[k]] = chosen[k];
  }
  for (var b = 0; b < bosses.length; b++) {
    assigned[bossSlots[b]] = bosses[b];
  }

  final out = <Level>[];
  for (var i = 0; i < kLevelsPerChapter; i++) {
    final c = assigned[i]!;
    final id = (chapter - 1) * kLevelsPerChapter + i + 1;
    final boss = id % 25 == 0;

    var moveLimit = c.level.moveLimit;
    if (boss) {
      if (moveLimit > 0) {
        // Tighter, but never below the solution we already proved exists. Boss
        // candidates were selected against this ceiling, so this really does
        // tighten, and it tightens past the chapter rather than past the
        // candidate's own par.
        moveLimit = _tightened(c, ceiling);
      } else {
        // An unlimited chapter. Section 6.4 wants every 25th level to carry a
        // tighter limit, and a boss with no limit at all is just an ordinary
        // level under a different banner, which is what chapters 1 and 2 used
        // to ship. Derive one from the solution the solver actually found, with
        // enough slack that a competent player is not forced into optimal play.
        moveLimit = (c.solutionMoves * 1.3).ceil();
      }
    }

    out.add(
      Level(
        id: id,
        chapter: chapter,
        goal: c.level.goal,
        target: c.level.target,
        moveLimit: moveLimit,
        preset: c.level.preset,
        shapePool: c.level.shapePool,
        seed: c.level.seed,
        starTargets: _starTargets(c),
        difficulty: c.difficulty,
      ),
    );
  }
  return out;
}

/// The limit a boss has to come in under: a tenth below what the chapter's
/// candidates average. The margin absorbs the shift from pulling four
/// candidates out of the pool for the boss slots, so the shipped bosses stay
/// under the shipped average and not merely under the pool's.
int _bossCeiling(List<Candidate> pool) {
  final limits = pool
      .map((c) => c.level.moveLimit)
      .where((l) => l > 0)
      .toList();
  if (limits.isEmpty) return 0;
  final average = limits.reduce((a, b) => a + b) / limits.length;
  return (average * 0.9).floor();
}

/// The move limit a boss level carries: 15% off its own par, held under the
/// chapter ceiling, but never below a solution the solver has actually found.
int _tightened(Candidate c, int ceiling) {
  final limit = c.level.moveLimit;
  if (limit <= 0) return limit;
  var tight = (limit * 0.85).floor();
  if (ceiling > 0 && tight > ceiling) tight = ceiling;
  return tight > c.solutionMoves ? tight : c.solutionMoves;
}

/// `[completion floor, 2 star, 3 star]`. One star is for completing at all, so
/// the first entry is only a floor. Two stars sits just under what a strong
/// solver run scored, which a competent player reaches by packing tighter.
List<int> _starTargets(Candidate c) {
  final s = c.solutionScore;
  return <int>[(s * 0.5).round(), (s * 0.95).round(), (s * 1.3).round()];
}

// ---------------------------------------------------------------------------
// Worker
// ---------------------------------------------------------------------------

class _Job {
  final int chapter;
  final int seedFrom;
  final int seedTo;
  final int nodeBudget;
  final int difficultyBudget;
  final int easyBudget;
  final int wanted;

  const _Job(
    this.chapter,
    this.seedFrom,
    this.seedTo,
    this.nodeBudget,
    this.difficultyBudget,
    this.easyBudget,
    this.wanted,
  );
}

List<Map<String, dynamic>> _work(_Job job) {
  final p = paramsFor(job.chapter);
  final out = <Map<String, dynamic>>[];
  for (var seed = job.seedFrom; seed < job.seedTo; seed++) {
    final level = buildCandidate(p, seed);
    if (level == null) continue;
    final c = evaluate(
      level,
      p,
      nodeBudget: job.nodeBudget,
      difficultyBudget: job.difficultyBudget,
      easyBudget: job.easyBudget,
    );
    if (c != null) {
      out.add(c.toWire());
      if (out.length >= job.wanted) break;
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  final chapters = opts.chapters;
  final outDir = Directory(opts.outDir);
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final perChapter = (opts.candidates / chapters.length).round();
  final workers = opts.isolates;

  stdout.writeln('Blocktopus level generator');
  stdout.writeln('  chapters   ${chapters.join(', ')}');
  stdout.writeln(
    '  candidates $perChapter per chapter (${opts.candidates} total)',
  );
  stdout.writeln('  isolates   $workers');
  stdout.writeln(
    '  budget     ${opts.nodeBudget} nodes, ${opts.difficultyBudget} per first move',
  );
  stdout.writeln('');

  final started = DateTime.now();

  for (final chapter in chapters) {
    final chStart = DateTime.now();
    final accepted = <Candidate>[];
    var seedBase = opts.seed + chapter * 1000003;
    var attempted = 0;

    // Keep dispatching rounds until we have enough, or we run out of budget.
    while (accepted.length < opts.keepPerChapter && attempted < perChapter) {
      final round = <Future<List<Map<String, dynamic>>>>[];
      // Each worker stops at its share of the target, not at the whole target,
      // otherwise the round only ends when every isolate has independently
      // found `keep` candidates and the run does `workers` times the work.
      final share = ((opts.keepPerChapter - accepted.length) / workers)
          .ceil()
          .clamp(1, opts.keepPerChapter);
      // A round ends when its slowest worker ends, so the seed range each
      // worker scans has to stay near what it actually needs. Handing out the
      // whole remaining budget makes one unlucky worker grind alone through
      // hundreds of seeds while the other six sit idle.
      final need = (share * 5).clamp(20, 400);
      final chunk = ((perChapter - attempted) / workers).ceil().clamp(1, need);
      for (var w = 0; w < workers; w++) {
        final from = seedBase + w * chunk;
        final job = _Job(
          chapter,
          from,
          from + chunk,
          opts.nodeBudget,
          opts.difficultyBudget,
          opts.easyBudget,
          share,
        );
        round.add(Isolate.run(() => _work(job)));
      }
      final results = await Future.wait(round);
      for (final r in results) {
        for (final m in r) {
          accepted.add(Candidate.fromWire(m));
        }
      }
      attempted += chunk * workers;
      seedBase += chunk * workers;
      stdout.write(
        '\r  chapter $chapter: ${accepted.length} accepted / $attempted tried   ',
      );
    }
    stdout.writeln('');

    if (accepted.length < kLevelsPerChapter) {
      stderr.writeln(
        '  chapter $chapter FAILED: ${accepted.length} of $kLevelsPerChapter. '
        'Raise --candidates or loosen the chapter parameters.',
      );
      exitCode = 1;
      continue;
    }

    final levels = curate(chapter, accepted);
    final info = chapterInfo(chapter);
    final file = File('${opts.outDir}/${info.assetPath.split('/').last}');
    file.writeAsStringSync(
      jsonEncode(<String, dynamic>{
        'chapter': chapter,
        'theme': info.theme,
        'levels': levels.map((l) => l.toJson()).toList(),
      }),
    );

    final took = DateTime.now().difference(chStart);
    final dMin = levels.map((l) => l.difficulty).reduce(min);
    final dMax = levels.map((l) => l.difficulty).reduce(max);
    stdout.writeln(
      '  chapter $chapter written: ${file.path} '
      '(difficulty ${dMin.toStringAsFixed(2)} to ${dMax.toStringAsFixed(2)}, '
      '${took.inSeconds}s, ${(file.lengthSync() / 1024).round()} KB)',
    );
  }

  stdout.writeln('');
  stdout.writeln('done in ${DateTime.now().difference(started).inSeconds}s');
}

class _Opts {
  final List<int> chapters;
  final int candidates;
  final int isolates;
  final int nodeBudget;
  final int difficultyBudget;
  final int easyBudget;
  final int seed;
  final String outDir;
  final int keepPerChapter;

  const _Opts({
    required this.chapters,
    required this.candidates,
    required this.isolates,
    required this.nodeBudget,
    required this.difficultyBudget,
    required this.easyBudget,
    required this.seed,
    required this.outDir,
    required this.keepPerChapter,
  });
}

_Opts _parseArgs(List<String> args) {
  var chapters = List<int>.generate(kChapterCount, (i) => i + 1);
  var candidates = 30000;
  var isolates = max(1, Platform.numberOfProcessors - 1);
  var nodeBudget = kGeneratorNodeBudget;
  var difficultyBudget = 6000;
  var easyBudget = 8000;
  var seed = 20260813;
  var outDir = 'assets/levels';
  var keep = 260;

  for (final a in args) {
    final i = a.indexOf('=');
    if (!a.startsWith('--') || i < 0) continue;
    final key = a.substring(2, i);
    final value = a.substring(i + 1);
    switch (key) {
      case 'chapters':
      case 'chapter':
        chapters = value.split(',').map((s) => int.parse(s.trim())).toList();
      case 'candidates':
        candidates = int.parse(value);
      case 'isolates':
        isolates = int.parse(value);
      case 'nodes':
        nodeBudget = int.parse(value);
      case 'diffnodes':
        difficultyBudget = int.parse(value);
      case 'easynodes':
        easyBudget = int.parse(value);
      case 'seed':
        seed = int.parse(value);
      case 'out':
        outDir = value;
      case 'keep':
        keep = int.parse(value);
    }
  }

  return _Opts(
    chapters: chapters,
    candidates: candidates,
    isolates: isolates,
    nodeBudget: nodeBudget,
    difficultyBudget: difficultyBudget,
    easyBudget: easyBudget,
    seed: seed,
    outDir: outDir,
    keepPerChapter: keep,
  );
}
