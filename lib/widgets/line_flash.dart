import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import 'piece_view.dart';

/// How long a completed line stays lit before it breaks apart, in frames at
/// 60fps. Long enough to read which line went and why, short enough that it
/// never feels like waiting for the game.
const int kFlashHoldFrames = 8; // ~130ms
const int kFlashFadeFrames = 7; // ~115ms

class LineFlash {
  final List<Rect> rects;
  final Color color;
  final double cellSize;
  final VoidCallback? onBreak;

  int age = 0;
  bool broken = false;

  LineFlash(this.rects, this.color, this.cellSize, this.onBreak);

  int get total => kFlashHoldFrames + kFlashFadeFrames;

  bool get done => age >= total;

  /// Solid while it holds, then fades out.
  double get opacity {
    if (age <= kFlashHoldFrames) return 1;
    final k = (age - kFlashHoldFrames) / kFlashFadeFrames;
    return (1 - k).clamp(0.0, 1.0);
  }
}

/// Lights a completed line up in the colour of the piece that finished it,
/// holds it for a beat, then lets it break apart.
///
/// The board clears instantly in `board_state.dart`, which stays pure and has
/// no idea any of this exists: the cells are already empty by the time this
/// paints over them. Deferring the real clear would mean an animation sitting
/// in the middle of the undo snapshots and the solver, which is a far worse
/// trade than painting the same blocks one more time.
class LineFlashController extends ChangeNotifier {
  final List<LineFlash> flashes = <LineFlash>[];

  /// Set by the layer so a flash can start the ticker.
  VoidCallback? onWake;

  bool get isEmpty => flashes.isEmpty;

  /// [onBreak] fires on the frame the fade starts, which is when the line
  /// should burst into particles. Driven by this controller's own ticker
  /// rather than a timer, so it stays in step with the fade and stays
  /// deterministic under `flutter test`.
  void flash(
    List<Rect> rects,
    Color color,
    double cellSize, {
    VoidCallback? onBreak,
  }) {
    if (rects.isEmpty) {
      onBreak?.call();
      return;
    }
    flashes.add(LineFlash(rects, color, cellSize, onBreak));
    onWake?.call();
    notifyListeners();
  }

  void tick() {
    if (flashes.isEmpty) return;
    for (var i = flashes.length - 1; i >= 0; i--) {
      final f = flashes[i];
      f.age++;
      if (!f.broken && f.age >= kFlashHoldFrames) {
        f.broken = true;
        f.onBreak?.call();
      }
      if (f.done) flashes.removeAt(i);
    }
    notifyListeners();
  }

  /// Drops everything without firing the pending callbacks. Used by Rewind:
  /// the placement is being taken back, so the line it cleared must not go on
  /// to throw particles for a clear that no longer happened.
  void clear() {
    flashes.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    onWake = null;
    flashes.clear();
    super.dispose();
  }
}

class LineFlashLayer extends StatefulWidget {
  final LineFlashController controller;

  const LineFlashLayer({super.key, required this.controller});

  @override
  State<LineFlashLayer> createState() => _LineFlashLayerState();
}

class _LineFlashLayerState extends State<LineFlashLayer>
    with SingleTickerProviderStateMixin {
  // Created eagerly: a lazy `late final` would be initialised by dispose()
  // itself, which looks up an ancestor on a deactivated element.
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.controller.onWake = _wake;
  }

  void _wake() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration _) {
    widget.controller.tick();
    if (widget.controller.isEmpty) _ticker.stop();
  }

  @override
  void dispose() {
    widget.controller.onWake = null;
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _LineFlashPainter(widget.controller),
        size: Size.infinite,
      ),
    );
  }
}

/// One painter for every live flash, for the same reason section 10.1 gives
/// for particles: a widget per cell would be dozens of layers for a quarter
/// of a second.
class _LineFlashPainter extends CustomPainter {
  final LineFlashController controller;

  _LineFlashPainter(this.controller) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in controller.flashes) {
      final o = f.opacity;
      if (o <= 0) continue;
      for (final rect in f.rects) {
        // The shared block painter, so a lit cell is the same shape, gloss and
        // shadow as the block it replaces. Anything else reads as an overlay.
        paintBlock(canvas, rect, f.color, f.cellSize, opacity: o);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineFlashPainter oldDelegate) => true;
}
