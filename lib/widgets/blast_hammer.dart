import 'dart:math';

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Draws the hammer with its handle end at [pivot], swung by [angle] from
/// resting on the point the handle points at.
///
/// Shared by the swing and by the hammer that hovers while the player is
/// choosing a block, so the two cannot drift into being different objects.
void _drawHammer(
  Canvas canvas,
  Offset pivot,
  double angle,
  double cell,
  double opacity,
) {
  final headW = cell * 1.05;
  final headH = cell * 0.62;
  final handleW = cell * 0.2;
  final handleL = cell * 1.45;

  Paint fill(Color c) => Paint()..color = c.withValues(alpha: opacity);

  canvas.save();
  canvas.translate(pivot.dx, pivot.dy);
  // `angle` lifts the whole arm about the pivot; the constant points that arm
  // down-left, so +x runs from the pivot to whatever is being hit.
  canvas.rotate(angle + 3 * pi / 4);

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(0, -handleW / 2, handleL, handleW),
      Radius.circular(handleW / 2),
    ),
    fill(inkPurple),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(handleW * 0.4, -handleW * 0.34, handleL * 0.7, handleW * 0.3),
      Radius.circular(handleW * 0.2),
    ),
    fill(Colors.white.withValues(alpha: 0.16)),
  );

  // The head sits across the end of the handle, square to it.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(handleL, 0), width: headH, height: headW),
      Radius.circular(cell * kCellRadiusFactor),
    ),
    fill(inkPurpleHi),
  );
  // The same gloss the blocks wear, so the hammer belongs to the same set of
  // objects as the thing it is hitting.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(handleL - headH * 0.22, 0),
        width: headH * 0.3,
        height: headW * 0.7,
      ),
      Radius.circular(cell * kGlossRadiusFactor),
    ),
    fill(Colors.white.withValues(alpha: 0.22)),
  );

  canvas.restore();
}

/// The hammer hovering at the edge of the board while the player picks a
/// block. This is the targeting state: it replaced a mascot arm reaching in,
/// which read as a tentacle rather than as the tool that is about to be used.
class BlastHammerReady extends StatefulWidget {
  const BlastHammerReady({super.key});

  @override
  State<BlastHammerReady> createState() => _BlastHammerReadyState();
}

class _BlastHammerReadyState extends State<BlastHammerReady>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _bob,
        builder: (context, _) => CustomPaint(painter: _ReadyPainter(_bob.value)),
      ),
    );
  }
}

class _ReadyPainter extends CustomPainter {
  final double phase;

  const _ReadyPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Sized off the viewport rather than plumbed through from the board: at
    // this width it matches a board cell, and it does not need to be exact.
    final cell = size.width * 0.11;
    final wave = sin(phase * 2 * pi);
    // Low and to the left, so it hangs off the bottom corner of the board
    // rather than sitting on top of cells the player might want to tap.
    final pivot = Offset(
      size.width * 0.055,
      size.height * 0.60 + wave * cell * 0.14,
    );
    // Held cocked, breathing slightly, so it reads as waiting to come down.
    _drawHammer(canvas, pivot, -1.05 + wave * 0.09, cell, 1);
  }

  @override
  bool shouldRepaint(_ReadyPainter old) => old.phase != phase;
}

/// The hammer that swings in and breaks a block during Ink Blast.
///
/// It flies in already raised, comes down hard on the cell, and recoils away.
/// The strike is the only part that matters, so it gets the least time: the
/// approach eases out, the fall eases *in* so the head accelerates into the
/// block rather than drifting onto it.
///
/// Painted in code like everything else the mascot owns, and in his colours,
/// so it reads as his arm's doing rather than as a tool borrowed from another
/// game.
class BlastHammer extends StatefulWidget {
  /// The cell being hit, in the coordinates of the stack this sits in.
  final Rect target;

  /// Fired once, on the frame the head lands. This is where the block should
  /// actually be removed.
  final VoidCallback onImpact;

  /// Fired when the recoil has finished and the widget can be taken down.
  final VoidCallback onDone;

  const BlastHammer({
    super.key,
    required this.target,
    required this.onImpact,
    required this.onDone,
  });

  /// Total swing. The caller needs this to know how long the board is frozen.
  static const Duration duration = Duration(milliseconds: 430);

  /// Where in the swing the head lands.
  static const double impactAt = 0.52;

  @override
  State<BlastHammer> createState() => _BlastHammerState();
}

class _BlastHammerState extends State<BlastHammer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swing;
  bool _struck = false;

  @override
  void initState() {
    super.initState();
    _swing = AnimationController(vsync: this, duration: BlastHammer.duration)
      ..addListener(_onTick)
      ..forward();
  }

  void _onTick() {
    // Driven off the animation rather than a Timer, so the impact lands on a
    // real frame and stays put under the test binding's fake clock.
    if (!_struck && _swing.value >= BlastHammer.impactAt) {
      _struck = true;
      widget.onImpact();
    }
    if (_swing.isCompleted) widget.onDone();
  }

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _swing,
        builder: (context, _) =>
            CustomPaint(painter: _HammerPainter(_swing.value, widget.target)),
      ),
    );
  }
}

class _HammerPainter extends CustomPainter {
  final double t;
  final Rect target;

  const _HammerPainter(this.t, this.target);

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    const impact = BlastHammer.impactAt;
    const approach = 0.3;

    // The head is as wide as the cell and a bit taller than half of it, so it
    // covers what it hits without swamping the board.
    final cell = target.width;
    final handleL = cell * 1.45;

    // Angle of the swing, and how far off its mark the hammer still is.
    // `offMark` is one scalar for both the fly in and the lift away, so the
    // handle never changes length: the whole hammer moves, it does not
    // telescope towards the cell.
    final double angle;
    final double offMark;
    double fade = 1;
    if (t < approach) {
      // Flying in, already cocked.
      offMark = 1 - Curves.easeOut.transform(t / approach);
      angle = -1.15;
    } else if (t < impact) {
      // The strike. easeIn, so the head is fastest at the moment it lands.
      final p = Curves.easeIn.transform((t - approach) / (impact - approach));
      offMark = 0;
      angle = -1.15 * (1 - p);
    } else {
      // Recoil and lift away, back the way it came.
      final p = Curves.easeOut.transform((t - impact) / (1 - impact));
      offMark = p * 0.55;
      angle = -0.7 * p;
      fade = 1 - p;
    }
    if (fade <= 0.01) return;

    // The pivot is the far end of the handle, fixed up and to the right of the
    // cell at 45 degrees, so the head arcs down onto the cell centre.
    const diagonal = 0.7071;
    final pivot =
        target.center + Offset(handleL * diagonal, -handleL * diagonal);
    final entry = Offset(offMark * cell * 2.4, -offMark * cell * 1.8);

    _drawHammer(canvas, pivot + entry, angle, cell, fade);

    // A ring of impact, thrown out from the cell on the frame the head lands.
    if (t >= impact) {
      final p = ((t - impact) / (1 - impact)).clamp(0.0, 1.0);
      canvas.drawCircle(
        target.center,
        cell * (0.35 + p * 0.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.09 * (1 - p)
          ..color = Colors.white.withValues(alpha: 0.5 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(_HammerPainter old) =>
      old.t != t || old.target != target;
}
