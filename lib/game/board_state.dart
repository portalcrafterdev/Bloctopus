/// The board: grid, placement, line detection and scoring.
///
/// Pure Dart. No Flutter imports. This file runs inside the offline level
/// generator and inside unit tests, so it must never reach for a widget.
library;

import '../models/level.dart';
import '../models/piece.dart';

const int kBoardSize = 8;
const int kCellCount = kBoardSize * kBoardSize;

/// Cell kinds. The values match the `preset` encoding in section 6.2.
class Cell {
  static const int empty = 0;

  /// Permanent. Cannot be filled, counts as filled for line detection, never
  /// disappears.
  static const int blocked = 1;

  /// A normal block, clearable.
  static const int filled = 2;

  /// Clears when a line passes through it.
  static const int jelly = 3;

  /// Two hits: becomes [jelly], then clears.
  static const int doubleJelly = 4;

  /// Two hits: becomes [filled], then clears normally.
  static const int stone = 5;

  /// An ordinary block carrying a star. It behaves exactly like [filled] -
  /// it fills its square, it completes lines, it clears in one hit - and the
  /// star is collected when it goes. Nothing about placement changes, which
  /// is the point: it is a reason to aim at a particular row, not a new rule
  /// to learn.
  static const int star = 6;

  static bool occupied(int kind) => kind != empty;

  /// Cells the player may remove with Ink Blast.
  static bool blastable(int kind) => kind != empty && kind != blocked;
}

/// What one placement did. Everything the UI needs for juice, and everything
/// the controller needs for goal tracking.
class PlacementResult {
  final bool ok;
  final int cellsPlaced;
  final int linesCleared;
  final int rowsCleared;
  final int colsCleared;
  final int scoreGained;
  final int streakAfter;

  /// Jelly cells fully removed by this placement.
  final int jellyCleared;

  /// Pre-filled preset blocks destroyed by this placement.
  final int blocksBroken;

  /// Stars collected by this placement, and where they were, so the screen can
  /// fly them to the goal banner.
  final List<int> starsCollected;

  /// Cell indices that visually emptied, with their colours, for particles.
  final List<int> clearedCells;
  final List<int> clearedColors;

  /// Cell indices the piece itself occupied.
  final List<int> placedCells;

  const PlacementResult({
    required this.ok,
    this.cellsPlaced = 0,
    this.linesCleared = 0,
    this.rowsCleared = 0,
    this.colsCleared = 0,
    this.scoreGained = 0,
    this.streakAfter = 0,
    this.jellyCleared = 0,
    this.blocksBroken = 0,
    this.starsCollected = const <int>[],
    this.clearedCells = const <int>[],
    this.clearedColors = const <int>[],
    this.placedCells = const <int>[],
  });

  static const PlacementResult rejected = PlacementResult(ok: false);
}

/// An 8x8 board plus the running score, streak and goal counters.
///
/// The counters live here rather than in the controller so that a single
/// [clone] is a complete, correct undo snapshot. See section 8.
class BoardState {
  final List<int> kinds;
  final List<int> colors; // palette index, -1 when empty
  final List<bool> fromPreset; // true for cells the level started with

  int score;
  int streak;

  /// Consecutive scoring placements. Drives the audio pitch ladder. It is the
  /// same counter as [streak]; kept named for section 11.2.
  int get clearStreak => streak;

  int linesCleared;
  int jellyCleared;
  int blocksBroken;
  int starsTaken;
  int movesUsed;

  BoardState._(
    this.kinds,
    this.colors,
    this.fromPreset, {
    this.score = 0,
    this.streak = 0,
    this.linesCleared = 0,
    this.jellyCleared = 0,
    this.blocksBroken = 0,
    this.starsTaken = 0,
    this.movesUsed = 0,
  });

  BoardState.empty()
    : kinds = List<int>.filled(kCellCount, Cell.empty),
      colors = List<int>.filled(kCellCount, -1),
      fromPreset = List<bool>.filled(kCellCount, false),
      score = 0,
      streak = 0,
      linesCleared = 0,
      jellyCleared = 0,
      blocksBroken = 0,
      starsTaken = 0,
      movesUsed = 0;

  /// Builds a board from a level preset. Colours are derived from the seed so
  /// the generator, the solver and the device all agree.
  factory BoardState.fromPreset(List<int> preset, int seed) {
    final b = BoardState.empty();
    for (var i = 0; i < kCellCount && i < preset.length; i++) {
      final k = preset[i];
      b.kinds[i] = k;
      b.fromPreset[i] = k != Cell.empty;
      b.colors[i] = k == Cell.empty
          ? -1
          : (k == Cell.blocked ? -1 : (seed ^ (i * 0x2545F491)) % kPaletteSize);
    }
    return b;
  }

  BoardState clone() => BoardState._(
    List<int>.of(kinds),
    List<int>.of(colors),
    List<bool>.of(fromPreset),
    score: score,
    streak: streak,
    linesCleared: linesCleared,
    jellyCleared: jellyCleared,
    blocksBroken: blocksBroken,
    starsTaken: starsTaken,
    movesUsed: movesUsed,
  );

  static int indexOf(int x, int y) => y * kBoardSize + x;

  int kindAt(int x, int y) => kinds[y * kBoardSize + x];

  bool isEmptyAt(int x, int y) => kinds[y * kBoardSize + x] == Cell.empty;

  int get filledCount {
    var n = 0;
    for (var i = 0; i < kCellCount; i++) {
      if (kinds[i] != Cell.empty) n++;
    }
    return n;
  }

  double get density => filledCount / kCellCount;

  /// Every cell of the shape must land on an empty in-bounds cell.
  bool canPlace(Shape s, int bx, int by) {
    if (bx < 0 || by < 0 || bx + s.w > kBoardSize || by + s.h > kBoardSize) {
      return false;
    }
    for (var i = 0; i < s.cells.length; i++) {
      final c = s.cells[i];
      final x = bx + c % s.w;
      final y = by + c ~/ s.w;
      if (kinds[y * kBoardSize + x] != Cell.empty) return false;
    }
    return true;
  }

  /// Is there anywhere at all this shape fits?
  bool hasPlacementFor(Shape s) {
    for (var by = 0; by + s.h <= kBoardSize; by++) {
      for (var bx = 0; bx + s.w <= kBoardSize; bx++) {
        if (canPlace(s, bx, by)) return true;
      }
    }
    return false;
  }

  /// Game over when no remaining tray piece fits anywhere.
  bool isGameOver(List<Piece?> tray) {
    for (final p in tray) {
      if (p != null && hasPlacementFor(p.shape)) return false;
    }
    return true;
  }

  List<(int, int)> placementsFor(Shape s) {
    final out = <(int, int)>[];
    for (var by = 0; by + s.h <= kBoardSize; by++) {
      for (var bx = 0; bx + s.w <= kBoardSize; bx++) {
        if (canPlace(s, bx, by)) out.add((bx, by));
      }
    }
    return out;
  }

  /// Places a piece and resolves every full row and column simultaneously.
  PlacementResult place(Shape s, int bx, int by, int colorIndex) {
    if (!canPlace(s, bx, by)) return PlacementResult.rejected;

    final placed = <int>[];
    for (var i = 0; i < s.cells.length; i++) {
      final c = s.cells[i];
      final idx = (by + c ~/ s.w) * kBoardSize + (bx + c % s.w);
      kinds[idx] = Cell.filled;
      colors[idx] = colorIndex;
      fromPreset[idx] = false;
      placed.add(idx);
    }

    // Detect all full rows and columns first, then clear them together.
    final rows = <int>[];
    final cols = <int>[];
    for (var y = 0; y < kBoardSize; y++) {
      var full = true;
      for (var x = 0; x < kBoardSize; x++) {
        if (kinds[y * kBoardSize + x] == Cell.empty) {
          full = false;
          break;
        }
      }
      if (full) rows.add(y);
    }
    for (var x = 0; x < kBoardSize; x++) {
      var full = true;
      for (var y = 0; y < kBoardSize; y++) {
        if (kinds[y * kBoardSize + x] == Cell.empty) {
          full = false;
          break;
        }
      }
      if (full) cols.add(x);
    }

    // A cell in both a cleared row and a cleared column takes one hit, not two.
    final hit = <int>{};
    for (final y in rows) {
      for (var x = 0; x < kBoardSize; x++) {
        hit.add(y * kBoardSize + x);
      }
    }
    for (final x in cols) {
      for (var y = 0; y < kBoardSize; y++) {
        hit.add(y * kBoardSize + x);
      }
    }

    final emptied = <int>[];
    final emptiedColors = <int>[];
    final stars = <int>[];
    var jelly = 0;
    var broken = 0;

    for (final idx in hit) {
      switch (kinds[idx]) {
        case Cell.blocked:
          break; // never disappears
        case Cell.star:
          // A star is a block with something on it: it clears like any other
          // block, and the star comes off with it.
          stars.add(idx);
          if (fromPreset[idx]) broken++;
          emptied.add(idx);
          emptiedColors.add(colors[idx]);
          kinds[idx] = Cell.empty;
          colors[idx] = -1;
          fromPreset[idx] = false;
        case Cell.filled:
          if (fromPreset[idx]) broken++;
          emptied.add(idx);
          emptiedColors.add(colors[idx]);
          kinds[idx] = Cell.empty;
          colors[idx] = -1;
          fromPreset[idx] = false;
        case Cell.jelly:
          jelly++;
          emptied.add(idx);
          emptiedColors.add(colors[idx]);
          kinds[idx] = Cell.empty;
          colors[idx] = -1;
          fromPreset[idx] = false;
        case Cell.doubleJelly:
          kinds[idx] = Cell.jelly; // softens, stays on the board
        case Cell.stone:
          kinds[idx] = Cell.filled; // softens into a normal block
      }
    }

    final lines = rows.length + cols.length;

    // Scoring, section 5.
    var gained = s.cells.length;
    if (lines > 0) {
      streak++;
      gained += lines * 10 * lines;
      if (streak > 1) gained += streak * 5;
    } else {
      streak = 0;
    }

    score += gained;
    linesCleared += lines;
    jellyCleared += jelly;
    blocksBroken += broken;
    starsTaken += stars.length;
    movesUsed++;

    return PlacementResult(
      ok: true,
      cellsPlaced: s.cells.length,
      linesCleared: lines,
      rowsCleared: rows.length,
      colsCleared: cols.length,
      scoreGained: gained,
      streakAfter: streak,
      jellyCleared: jelly,
      blocksBroken: broken,
      starsCollected: stars,
      clearedCells: emptied,
      clearedColors: emptiedColors,
      placedCells: placed,
    );
  }

  /// Ink Blast. Removes one cell without scoring and without touching the
  /// streak. Cannot target blocked cells.
  ///
  /// A blasted jelly or preset block still counts towards its goal, otherwise
  /// the booster could strand a level in an unwinnable state.
  bool blast(int index) {
    if (index < 0 || index >= kCellCount) return false;
    final kind = kinds[index];
    if (!Cell.blastable(kind)) return false;
    if (kind == Cell.jelly || kind == Cell.doubleJelly) jellyCleared++;
    if (kind == Cell.star) starsTaken++;
    if ((kind == Cell.filled || kind == Cell.star) && fromPreset[index]) {
      blocksBroken++;
    }
    kinds[index] = Cell.empty;
    colors[index] = -1;
    fromPreset[index] = false;
    return true;
  }

  /// One bit per occupied cell.
  int get occupancy {
    var bits = 0;
    for (var i = 0; i < kCellCount; i++) {
      if (kinds[i] != Cell.empty) bits |= 1 << i;
    }
    return bits;
  }

  /// Distinguishes boards that share an occupancy but differ in special cells.
  int get specialHash {
    var h = 0x811C9DC5;
    for (var i = 0; i < kCellCount; i++) {
      final k = kinds[i];
      if (k >= Cell.jelly || k == Cell.blocked) {
        h = (h ^ (i * 6 + k)) * 0x01000193;
        h &= 0x3FFFFFFFFFFFFFFF;
      }
    }
    return h;
  }

  /// True when the goal for [level] has been met.
  bool goalMet(Level level) {
    switch (level.goal) {
      case GoalType.clearLines:
        return linesCleared >= level.target;
      case GoalType.reachScore:
        return score >= level.target;
      case GoalType.breakBlocks:
        return blocksBroken >= level.target;
      case GoalType.clearJelly:
        return jellyCleared >= level.target;
      case GoalType.survive:
        return movesUsed >= level.target;
      case GoalType.collectStars:
        return starsTaken >= level.target;
    }
  }

  /// Progress towards the goal, for the HUD banner.
  int goalProgress(Level level) {
    switch (level.goal) {
      case GoalType.clearLines:
        return linesCleared;
      case GoalType.reachScore:
        return score;
      case GoalType.breakBlocks:
        return blocksBroken;
      case GoalType.clearJelly:
        return jellyCleared;
      case GoalType.survive:
        return movesUsed;
      case GoalType.collectStars:
        return starsTaken;
    }
  }

  /// Area of the largest all-empty rectangle. Used by the solver's placement
  /// ordering and by the greedy baseline player.
  int largestEmptyRect() {
    final heights = List<int>.filled(kBoardSize, 0);
    var best = 0;
    for (var y = 0; y < kBoardSize; y++) {
      for (var x = 0; x < kBoardSize; x++) {
        heights[x] = kinds[y * kBoardSize + x] == Cell.empty
            ? heights[x] + 1
            : 0;
      }
      best = _largestRectInHistogram(heights, best);
    }
    return best;
  }

  @override
  String toString() {
    final sb = StringBuffer();
    for (var y = 0; y < kBoardSize; y++) {
      for (var x = 0; x < kBoardSize; x++) {
        sb.write(kinds[y * kBoardSize + x]);
      }
      sb.writeln();
    }
    return sb.toString();
  }
}

int _largestRectInHistogram(List<int> h, int best) {
  final stack = <int>[];
  var out = best;
  for (var i = 0; i <= h.length; i++) {
    final cur = i == h.length ? 0 : h[i];
    while (stack.isNotEmpty && h[stack.last] >= cur) {
      final height = h[stack.removeLast()];
      final width = stack.isEmpty ? i : i - stack.last - 1;
      final area = height * width;
      if (area > out) out = area;
    }
    stack.add(i);
  }
  return out;
}
