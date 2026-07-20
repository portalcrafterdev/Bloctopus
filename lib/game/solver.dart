/// Depth limited search over placements.
///
/// Pure Dart. No Flutter imports. The same code validates levels offline in
/// `tool/generate_levels.dart` and answers hint requests on device, with a
/// smaller node budget. See section 6.5.
library;

import '../models/level.dart';
import '../models/piece.dart';
import 'board_state.dart';

/// Node budget for the offline generator.
const int kGeneratorNodeBudget = 200000;

/// Node budget on device. If the solver blows through it we fall back to the
/// best greedy move rather than stalling the frame.
const int kDeviceNodeBudget = 20000;

class Move {
  final int slot; // tray slot 0..2
  final int shapeIndex;
  final int colorIndex;
  final int bx;
  final int by;

  const Move({
    required this.slot,
    required this.shapeIndex,
    required this.colorIndex,
    required this.bx,
    required this.by,
  });

  Shape get shape => kShapes[shapeIndex];

  @override
  String toString() => 'Move(slot $slot, ${shape.name} at $bx,$by)';
}

class SolveResult {
  final bool solved;
  final List<Move> solution;
  final int nodes;
  final bool budgetExceeded;

  const SolveResult({
    required this.solved,
    this.solution = const <Move>[],
    this.nodes = 0,
    this.budgetExceeded = false,
  });

  int get moves => solution.length;
}

/// A snapshot of everything a search node needs.
class GameSnapshot {
  final BoardState board;
  final List<Piece?> tray;
  final int nextIndex; // next unused index in the piece sequence

  const GameSnapshot(this.board, this.tray, this.nextIndex);

  GameSnapshot clone() =>
      GameSnapshot(board.clone(), List<Piece?>.of(tray), nextIndex);
}

class Solver {
  final Level level;
  final int nodeBudget;

  /// Cap on how many ordered candidates each node explores. Full width at the
  /// root so the difficulty metric stays honest.
  final int beamWidth;

  late final PieceSequence _seq = PieceSequence(level.seed, level.shapePool);

  int _nodes = 0;
  bool _aborted = false;
  final Set<int> _failed = <int>{};

  Solver(
    this.level, {
    this.nodeBudget = kGeneratorNodeBudget,
    this.beamWidth = 48,
  });

  int get nodesUsed => _nodes;

  /// The state a fresh level starts in.
  GameSnapshot initialState() => GameSnapshot(
    BoardState.fromPreset(level.preset, level.seed),
    _seq.trayAt(0),
    3,
  );

  /// Searches for a way to meet the goal within [limit] moves. `limit` defaults
  /// to the level's own move limit; a level with no limit is capped so the
  /// search terminates.
  SolveResult solve({int? limit, GameSnapshot? from}) {
    _nodes = 0;
    _aborted = false;
    _failed.clear();
    final depth = limit ?? _effectiveMoveLimit;
    final start = (from ?? initialState()).clone();
    final path = <Move>[];
    final ok = _dfs(start, 0, depth, path);
    return SolveResult(
      solved: ok,
      solution: ok ? List<Move>.of(path) : const <Move>[],
      nodes: _nodes,
      budgetExceeded: _aborted,
    );
  }

  int get _effectiveMoveLimit =>
      level.moveLimit > 0 ? level.moveLimit : _unlimitedCap;

  /// An unlimited level still needs a search horizon. 40 placements is well
  /// past anything a curated level should need.
  static const int _unlimitedCap = 40;

  bool _dfs(GameSnapshot s, int depth, int limit, List<Move> path) {
    if (s.board.goalMet(level)) return true;
    if (depth >= limit) return false;
    if (_nodes >= nodeBudget) {
      _aborted = true;
      return false;
    }
    _nodes++;

    // The tray refills only when all three slots are empty.
    var tray = s.tray;
    var nextIndex = s.nextIndex;
    if (tray[0] == null && tray[1] == null && tray[2] == null) {
      tray = _seq.trayAt(nextIndex);
      nextIndex += 3;
    }

    final key = _memoKey(s.board, tray, nextIndex, limit - depth);
    if (_failed.contains(key)) return false;

    final candidates = _orderedCandidates(s.board, tray, depth);
    if (candidates.isEmpty) {
      _failed.add(key); // game over on this branch
      return false;
    }

    final width = depth == 0 ? candidates.length : beamWidth;
    final n = candidates.length < width ? candidates.length : width;

    for (var i = 0; i < n; i++) {
      final m = candidates[i].move;
      final next = GameSnapshot(
        s.board.clone(),
        List<Piece?>.of(tray),
        nextIndex,
      );
      next.board.place(m.shape, m.bx, m.by, m.colorIndex);
      next.tray[m.slot] = null;

      path.add(m);
      if (_dfs(next, depth + 1, limit, path)) return true;
      path.removeLast();

      if (_aborted) return false;
    }

    _failed.add(key);
    return false;
  }

  /// Only failures are memoised, so a hash collision can at worst prune a live
  /// branch. That costs us a level candidate, never a wrong "solvable".
  int _memoKey(BoardState b, List<Piece?> tray, int nextIndex, int movesLeft) {
    var h = b.occupancy;
    h = _mix(h, b.specialHash);
    var trayMask = 0;
    for (var i = 0; i < tray.length; i++) {
      if (tray[i] != null) trayMask |= (tray[i]!.shapeIndex + 1) << (i * 7);
    }
    h = _mix(h, trayMask);
    h = _mix(h, nextIndex * 131 + movesLeft);
    h = _mix(h, b.goalProgress(level));
    return h;
  }

  /// Placement ordering, section 6.5: line completions first, then placements
  /// that touch existing blocks, then the ones that keep the largest empty
  /// rectangle intact.
  ///
  /// The rectangle term needs a trial placement, so it is only computed near
  /// the root, where ordering actually changes the shape of the search. Deeper
  /// down the first two terms carry the ordering and the extra 64 cell scan per
  /// candidate would dominate the node budget.
  List<_Candidate> _orderedCandidates(
    BoardState board,
    List<Piece?> tray,
    int depth,
  ) {
    final out = <_Candidate>[];
    for (var slot = 0; slot < tray.length; slot++) {
      final piece = tray[slot];
      if (piece == null) continue;
      final s = piece.shape;
      for (var by = 0; by + s.h <= kBoardSize; by++) {
        for (var bx = 0; bx + s.w <= kBoardSize; bx++) {
          if (!board.canPlace(s, bx, by)) continue;
          final lines = _linesCompleted(board, s, bx, by);
          final touch = _adjacency(board, s, bx, by);
          out.add(
            _Candidate(
              Move(
                slot: slot,
                shapeIndex: piece.shapeIndex,
                colorIndex: piece.colorIndex,
                bx: bx,
                by: by,
              ),
              lines * 100000 + touch * 100,
            ),
          );
        }
      }
    }

    if (depth <= 2) {
      for (final c in out) {
        c.score += _rectAfter(board, c.move.shape, c.move.bx, c.move.by);
      }
    }

    out.sort((a, b) {
      final d = b.score - a.score;
      if (d != 0) return d;
      // Deterministic tie break so generation is reproducible.
      final p = a.move.by * kBoardSize + a.move.bx;
      final q = b.move.by * kBoardSize + b.move.bx;
      return p != q ? p - q : a.move.slot - b.move.slot;
    });
    return out;
  }

  /// Best next move for the on-device hint. Falls back to the greedy pick when
  /// the budget runs out.
  Move? bestMove(GameSnapshot state, {int? movesLeft}) {
    final limit = movesLeft ?? _effectiveMoveLimit;
    if (limit <= 0) return null;
    final saved = nodeBudget;
    final r = Solver(
      level,
      nodeBudget: saved,
      beamWidth: beamWidth,
    ).solve(limit: limit, from: state);
    if (r.solved && r.solution.isNotEmpty) return r.solution.first;
    return greedyMove(state);
  }

  /// The greedy baseline player: best immediate placement, no lookahead.
  /// A shipped level must defeat it.
  Move? greedyMove(GameSnapshot s) {
    var tray = s.tray;
    if (tray[0] == null && tray[1] == null && tray[2] == null) {
      tray = _seq.trayAt(s.nextIndex);
    }
    final c = _orderedCandidates(s.board, tray, 0);
    return c.isEmpty ? null : c.first.move;
  }

  /// Plays the level with the greedy baseline. Returns true if greedy wins.
  bool greedySolves() => greedySolvesWithin(_effectiveMoveLimit);

  /// Greedy baseline, capped at [limit] placements. The generator uses the
  /// chapter par here, which is what makes the check meaningful on levels that
  /// ship with no move limit.
  bool greedySolvesWithin(int limit) {
    var state = initialState();
    for (var i = 0; i < limit; i++) {
      if (state.board.goalMet(level)) return true;
      var tray = state.tray;
      var nextIndex = state.nextIndex;
      if (tray[0] == null && tray[1] == null && tray[2] == null) {
        tray = _seq.trayAt(nextIndex);
        nextIndex += 3;
      }
      final candidates = _orderedCandidates(state.board, tray, 0);
      if (candidates.isEmpty) return false; // stuck
      final m = candidates.first.move;
      final board = state.board;
      board.place(m.shape, m.bx, m.by, m.colorIndex);
      final newTray = List<Piece?>.of(tray)..[m.slot] = null;
      state = GameSnapshot(board, newTray, nextIndex);
    }
    return state.board.goalMet(level);
  }

  /// `1 - (winning first moves / total legal first moves)`, section 6.4 step 6.
  ///
  /// [limit] must be the length of an efficient solution, not the level's move
  /// limit. Measured against a slack budget - and especially against the
  /// fallback horizon that unlimited levels would otherwise use - almost every
  /// first move stays winning and the metric collapses to zero for the whole
  /// chapter, which leaves nothing to sort the difficulty curve by.
  ///
  /// Each first move is re-solved with its own smaller budget; a move whose
  /// sub-search runs out of budget counts as not winning, which biases the
  /// score up rather than down.
  /// A full board offers well over a hundred legal first moves, and each one
  /// costs its own sub-search. Beyond a few dozen the ratio stops moving, so
  /// the sweep samples an even spread rather than solving from every move.
  /// The metric only has to order levels against each other.
  static const int _difficultySampleCap = 40;

  double difficulty({
    int perMoveBudget = 6000,
    int? limit,
    int sampleCap = _difficultySampleCap,
  }) {
    final start = initialState();
    final all = _orderedCandidates(start.board, start.tray, 0);
    if (all.isEmpty) return 1;
    final depth = limit ?? _effectiveMoveLimit;

    final sampled = <_Candidate>[];
    if (all.length <= sampleCap) {
      sampled.addAll(all);
    } else {
      for (var i = 0; i < sampleCap; i++) {
        sampled.add(all[(i * (all.length - 1) / (sampleCap - 1)).round()]);
      }
    }

    var winning = 0;
    for (final c in sampled) {
      final next = start.clone();
      next.board.place(c.move.shape, c.move.bx, c.move.by, c.move.colorIndex);
      next.tray[c.move.slot] = null;
      final sub = Solver(
        level,
        nodeBudget: perMoveBudget,
        beamWidth: beamWidth,
      );
      if (sub.solve(limit: depth - 1, from: next).solved) winning++;
    }
    return 1 - winning / sampled.length;
  }
}

class _Candidate {
  final Move move;
  int score;

  _Candidate(this.move, this.score);
}

/// How many rows and columns this placement would complete. Counted without
/// touching the board.
int _linesCompleted(BoardState b, Shape s, int bx, int by) {
  var count = 0;
  for (var dy = 0; dy < s.h; dy++) {
    final y = by + dy;
    var full = true;
    for (var x = 0; x < kBoardSize; x++) {
      if (b.kinds[y * kBoardSize + x] != Cell.empty) continue;
      if (!s.covers(x - bx, y - by)) {
        full = false;
        break;
      }
    }
    if (full) count++;
  }
  for (var dx = 0; dx < s.w; dx++) {
    final x = bx + dx;
    var full = true;
    for (var y = 0; y < kBoardSize; y++) {
      if (b.kinds[y * kBoardSize + x] != Cell.empty) continue;
      if (!s.covers(x - bx, y - by)) {
        full = false;
        break;
      }
    }
    if (full) count++;
  }
  return count;
}

/// Neighbours of the placed cells that are already occupied or off the board.
/// Placements that hug what is already there leave cleaner space behind.
int _adjacency(BoardState b, Shape s, int bx, int by) {
  var n = 0;
  for (var i = 0; i < s.cells.length; i++) {
    final c = s.cells[i];
    final x = bx + c % s.w;
    final y = by + c ~/ s.w;
    for (final d in const <List<int>>[
      <int>[1, 0],
      <int>[-1, 0],
      <int>[0, 1],
      <int>[0, -1],
    ]) {
      final nx = x + d[0];
      final ny = y + d[1];
      if (nx < 0 || ny < 0 || nx >= kBoardSize || ny >= kBoardSize) {
        n++;
      } else if (b.kinds[ny * kBoardSize + nx] != Cell.empty &&
          !s.covers(nx - bx, ny - by)) {
        n++;
      }
    }
  }
  return n;
}

/// Largest empty rectangle left behind, computed on a temporarily mutated
/// board so no allocation is needed.
int _rectAfter(BoardState b, Shape s, int bx, int by) {
  final touched = <int>[];
  for (var i = 0; i < s.cells.length; i++) {
    final c = s.cells[i];
    final idx = (by + c ~/ s.w) * kBoardSize + (bx + c % s.w);
    b.kinds[idx] = Cell.filled;
    touched.add(idx);
  }
  final area = b.largestEmptyRect();
  for (final idx in touched) {
    b.kinds[idx] = Cell.empty;
  }
  return area;
}

int _mix(int a, int b) {
  var z = a ^ (b * 0x9E3779B97F4A7C15);
  z ^= (z >> 29);
  z *= 0xBF58476D1CE4E5B9;
  z ^= (z >> 32);
  return z & 0x3FFFFFFFFFFFFFFF;
}
