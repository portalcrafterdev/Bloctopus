import 'package:flutter/foundation.dart';

import '../models/level.dart';
import '../models/piece.dart';
import '../models/save_data.dart';
import 'board_state.dart';

enum LevelStatus { playing, won, lost }

enum LossReason { none, outOfMoves, stuck }

/// Everything the juice layer needs to know about one placement.
class PlacementEvent {
  final PlacementResult result;
  final int slot;
  final int bx;
  final int by;

  /// Palette index of the piece that was placed. The line flash paints in it,
  /// so a clear reads as having been caused by the piece the player just put
  /// down rather than as the board deciding something on its own.
  final int colorIndex;

  const PlacementEvent(
    this.result,
    this.slot,
    this.bx,
    this.by,
    this.colorIndex,
  );
}

typedef PlacementListener = void Function(PlacementEvent event);

/// One entry on the undo stack. A full snapshot, so Rewind restores the board,
/// score, streak, tray and goal counters exactly. See section 8.
class _Snapshot {
  final BoardState board;
  final List<Piece?> tray;
  final int nextIndex;
  final bool trayIsFresh;

  const _Snapshot(this.board, this.tray, this.nextIndex, this.trayIsFresh);
}

class GameController extends ChangeNotifier {
  final Level level;
  final SaveData save;

  late BoardState board;
  late List<Piece?> tray;
  late int nextIndex;
  late PieceSequence _seq;

  LevelStatus status = LevelStatus.playing;
  LossReason lossReason = LossReason.none;

  /// Ink Blast targeting mode.
  bool blastMode = false;

  /// True while the tray holds three untouched pieces, which disables
  /// Reshuffle.
  bool trayIsFresh = true;

  final List<_Snapshot> _undo = <_Snapshot>[];
  static const int _undoCap = 5;

  final List<PlacementListener> _placementListeners = <PlacementListener>[];
  final List<VoidCallback> _boosterListeners = <VoidCallback>[];

  /// Booster award decided when the level finished, surfaced on the result
  /// screen.
  String? awardedBooster;

  GameController({required this.level, required this.save}) {
    _seq = PieceSequence(level.seed, level.shapePool);
    board = BoardState.fromPreset(level.preset, level.seed);
    tray = _seq.trayAt(0);
    nextIndex = 3;
  }

  // -- derived state --------------------------------------------------------

  int get score => board.score;

  int get streak => board.streak;

  int get movesUsed => board.movesUsed;

  /// null when the level has no move limit.
  int? get movesLeft =>
      level.moveLimit > 0 ? level.moveLimit - board.movesUsed : null;

  int get goalProgress => board.goalProgress(level);

  int get goalTarget => level.target;

  double get goalFraction =>
      level.target <= 0 ? 1 : (goalProgress / level.target).clamp(0, 1);

  bool get canUndo =>
      _undo.isNotEmpty &&
      status == LevelStatus.playing &&
      save.hasBooster(BoosterId.undo);

  bool get canReshuffle =>
      !trayIsFresh &&
      status == LevelStatus.playing &&
      save.hasBooster(BoosterId.refresh);

  bool get canBlast =>
      status == LevelStatus.playing &&
      save.hasBooster(BoosterId.hammer) &&
      board.filledCount > 0;

  /// Used by the mascot's `worried` state.
  int get validPlacementCount {
    var n = 0;
    for (final p in tray) {
      if (p == null) continue;
      n += board.placementsFor(p.shape).length;
    }
    return n;
  }

  int get stars {
    if (status != LevelStatus.won) return 0;
    final t = level.starTargets;
    if (t.length >= 3 && score >= t[2]) return 3;
    if (t.length >= 2 && score >= t[1]) return 2;
    return 1;
  }

  LevelResult get result => LevelResult(
    won: status == LevelStatus.won,
    stars: stars,
    score: score,
    movesUsed: board.movesUsed,
    linesCleared: board.linesCleared,
    boosterAwarded: awardedBooster,
  );

  // -- listeners ------------------------------------------------------------

  void addPlacementListener(PlacementListener l) => _placementListeners.add(l);

  void removePlacementListener(PlacementListener l) =>
      _placementListeners.remove(l);

  void addBoosterListener(VoidCallback l) => _boosterListeners.add(l);

  void removeBoosterListener(VoidCallback l) => _boosterListeners.remove(l);

  void _emitPlacement(PlacementEvent e) {
    for (final l in List<PlacementListener>.of(_placementListeners)) {
      l(e);
    }
  }

  void _emitBooster() {
    for (final l in List<VoidCallback>.of(_boosterListeners)) {
      l();
    }
  }

  // -- core loop ------------------------------------------------------------

  bool canPlace(int slot, int bx, int by) {
    if (status != LevelStatus.playing || blastMode) return false;
    final piece = tray[slot];
    if (piece == null) return false;
    return board.canPlace(piece.shape, bx, by);
  }

  bool place(int slot, int bx, int by) {
    if (!canPlace(slot, bx, by)) return false;
    final piece = tray[slot]!;

    _pushSnapshot();

    final r = board.place(piece.shape, bx, by, piece.colorIndex);
    if (!r.ok) {
      _undo.removeLast();
      return false;
    }

    tray[slot] = null;
    trayIsFresh = false;

    // The tray refills only when all three slots are empty.
    if (tray[0] == null && tray[1] == null && tray[2] == null) {
      tray = _seq.trayAt(nextIndex);
      nextIndex += 3;
      trayIsFresh = true;
    }

    _emitPlacement(PlacementEvent(r, slot, bx, by, piece.colorIndex));
    _evaluate();
    notifyListeners();
    return true;
  }

  void _evaluate() {
    if (status != LevelStatus.playing) return;

    if (board.goalMet(level)) {
      status = LevelStatus.won;
      _finish();
      return;
    }
    if (level.moveLimit > 0 && board.movesUsed >= level.moveLimit) {
      status = LevelStatus.lost;
      lossReason = LossReason.outOfMoves;
      return;
    }
    if (board.isGameOver(tray)) {
      status = LevelStatus.lost;
      lossReason = LossReason.stuck;
    }
  }

  void _finish() {
    awardedBooster = save.recordResult(level.id, stars, score);
  }

  // -- boosters -------------------------------------------------------------

  void _pushSnapshot() {
    _undo.add(
      _Snapshot(board.clone(), List<Piece?>.of(tray), nextIndex, trayIsFresh),
    );
    while (_undo.length > _undoCap) {
      _undo.removeAt(0);
    }
  }

  /// Rewind. Costs one booster and restores the previous state exactly.
  bool undo() {
    if (!canUndo) return false;
    if (!save.spendBooster(BoosterId.undo)) return false;
    final s = _undo.removeLast();
    board = s.board;
    tray = List<Piece?>.of(s.tray);
    nextIndex = s.nextIndex;
    trayIsFresh = s.trayIsFresh;
    status = LevelStatus.playing;
    lossReason = LossReason.none;
    blastMode = false;
    _emitBooster();
    notifyListeners();
    return true;
  }

  /// Ink Blast. Enters targeting mode; the booster is only spent once a cell
  /// is actually hit.
  void startBlast() {
    if (!canBlast) return;
    blastMode = true;
    notifyListeners();
  }

  void cancelBlast() {
    if (!blastMode) return;
    blastMode = false;
    notifyListeners();
  }

  bool blastAt(int cellIndex) {
    if (!blastMode || status != LevelStatus.playing) return false;
    if (!Cell.blastable(board.kinds[cellIndex])) return false;
    if (!save.spendBooster(BoosterId.hammer)) return false;

    _pushSnapshot();
    board.blast(cellIndex);
    blastMode = false;
    _emitBooster();
    _evaluate();
    notifyListeners();
    return true;
  }

  /// Reshuffle. Replaces all three tray pieces from the level's shape pool.
  bool reshuffle() {
    if (!canReshuffle) return false;
    if (!save.spendBooster(BoosterId.refresh)) return false;

    _pushSnapshot();
    tray = _seq.trayAt(nextIndex);
    nextIndex += 3;
    trayIsFresh = true;
    _emitBooster();

    // A reshuffle can itself end the level if nothing new fits either.
    if (board.isGameOver(tray) && !board.goalMet(level)) {
      status = LevelStatus.lost;
      lossReason = LossReason.stuck;
    }
    notifyListeners();
    return true;
  }

  /// Restarts the level from its preset. Boosters already spent stay spent.
  void restart() {
    board = BoardState.fromPreset(level.preset, level.seed);
    tray = _seq.trayAt(0);
    nextIndex = 3;
    trayIsFresh = true;
    status = LevelStatus.playing;
    lossReason = LossReason.none;
    blastMode = false;
    awardedBooster = null;
    _undo.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _placementListeners.clear();
    _boosterListeners.clear();
    super.dispose();
  }
}
