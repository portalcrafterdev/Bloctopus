import 'dart:math';

import 'package:flutter/material.dart';

/// A drift of tumbling blocks, painted behind the home screen title.
///
/// They are tonal rather than coloured: a darker and a lighter wash of
/// whatever the gradient happens to be at that height, so the field works over
/// any background and never competes with the block palette, which has to stay
/// the thing the eye reads as "a block you can place".
///
/// Seeded and static. A random scatter that reshuffles on every rebuild would
/// flicker, and would make the home screen golden untestable.
class BlockField extends StatelessWidget {
  /// Fraction of the height the drift covers before it has faded out entirely.
  final double depth;

  const BlockField({super.key, this.depth = 0.62});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _BlockFieldPainter(depth), size: Size.infinite),
    );
  }
}

class _BlockFieldPainter extends CustomPainter {
  final double depth;

  const _BlockFieldPainter(this.depth);

  /// Fixed, so the scatter is the same every frame and every run.
  static const int _seed = 20260814;
  static const int _count = 38;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rnd = Random(_seed);
    final band = size.height * depth;

    for (var i = 0; i < _count; i++) {
      // Biased towards the top: the drift should thin out as it falls, not
      // spread evenly down the screen.
      final t = pow(rnd.nextDouble(), 1.8).toDouble();
      final y = t * band;
      final x = rnd.nextDouble() * size.width;
      final side = size.width * (0.045 + rnd.nextDouble() * 0.075);
      final angle = (rnd.nextDouble() - 0.5) * 0.7;

      // Fades with depth, so the field dissolves into the gradient rather than
      // stopping at a line.
      final fade = (1 - t).clamp(0.0, 1.0);
      final shade = 0.05 + fade * 0.13;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: side,
        height: side,
      );
      final radius = Radius.circular(side * 0.22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = Colors.black.withValues(alpha: shade),
      );
      // One lit face along the top edge, which is what turns a dark square
      // into a block with a direction.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left + side * 0.16,
            rect.top + side * 0.12,
            side * 0.68,
            side * 0.24,
          ),
          Radius.circular(side * 0.12),
        ),
        Paint()..color = Colors.white.withValues(alpha: shade * 0.42),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BlockFieldPainter old) => old.depth != depth;
}
