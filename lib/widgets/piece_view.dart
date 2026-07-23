import 'dart:math';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/board_state.dart';
import '../models/piece.dart';

/// Stone cells read as scenery rather than as a block colour.
const Color _stoneFill = Color(0xFF6E6690);
const Color _stoneFillHi = Color(0xFF8A82AE);

/// Draws one filled block. Every filled block in the game goes through here so
/// the gloss and the shadow are identical everywhere. See section 3.
void paintBlock(
  Canvas canvas,
  Rect cellRect,
  Color color,
  double cellSize, {
  double opacity = 1,
  bool shadow = true,
}) {
  final inset = cellSize * kCellInsetFactor;
  final r = cellRect.deflate(inset);
  if (r.width <= 0 || r.height <= 0) return;
  final radius = Radius.circular(cellSize * kCellRadiusFactor);
  final rr = RRect.fromRectAndRadius(r, radius);

  if (shadow && opacity >= 1) {
    canvas.drawRRect(
      rr.shift(const Offset(0, 2)),
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8 * 0.57735),
    );
  }

  // Bevel. The whole square is the block's darker side wall; a slightly
  // smaller face is raised onto it, so the block reads as a solid object with
  // depth rather than as a flat rounded square.
  final wall = HSLColor.fromColor(color);
  canvas.drawRRect(
    rr,
    Paint()
      ..color = wall
          .withLightness((wall.lightness * 0.72).clamp(0.0, 1.0))
          .withSaturation((wall.saturation * 1.05).clamp(0.0, 1.0))
          .toColor()
          .withValues(alpha: opacity),
  );

  // The lit face, inset all round and lifted towards the top left, which is
  // where the gloss below implies the light is coming from.
  final lift = r.height * 0.10;
  final face = Rect.fromLTWH(
    r.left + r.width * 0.07,
    r.top + r.height * 0.05,
    r.width * 0.86,
    r.height * 0.86 - lift * 0.2,
  );
  if (face.width > 0 && face.height > 0) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        face,
        Radius.circular(cellSize * kCellRadiusFactor * 0.8),
      ),
      Paint()..color = color.withValues(alpha: opacity),
    );
  }

  // Gloss: white 22%, 70% width, 30% height, aligned top centre.
  final gw = r.width * 0.7;
  final gh = r.height * 0.3;
  final gloss = Rect.fromLTWH(
    r.left + (r.width - gw) / 2,
    r.top + r.height * 0.09,
    gw,
    gh,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      gloss,
      Radius.circular(cellSize * kGlossRadiusFactor),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.22 * opacity),
  );
}

/// Draws any board cell, including empty, blocked and the special kinds.
void paintCell(
  Canvas canvas,
  Rect cellRect,
  double cellSize,
  int kind,
  int colorIndex, {

  /// Empty cells alternate between two shades so the grid reads as a board
  /// rather than as one flat panel. Filled cells ignore it: a block covers
  /// its square completely.
  bool altSquare = false,
}) {
  final inset = cellSize * kCellInsetFactor;
  final r = cellRect.deflate(inset);
  final radius = Radius.circular(cellSize * kCellRadiusFactor);
  final rr = RRect.fromRectAndRadius(r, radius);

  switch (kind) {
    case Cell.empty:
      canvas.drawRRect(
        rr,
        Paint()..color = altSquare ? cellEmptyAlt : cellEmpty,
      );

    case Cell.blocked:
      canvas.drawRRect(rr, Paint()..color = cellBlocked);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(r.width * 0.18), radius),
        Paint()..color = Colors.black.withValues(alpha: 0.22),
      );

    case Cell.filled:
      paintBlock(canvas, cellRect, paletteColor(colorIndex), cellSize);

    case Cell.jelly:
      paintBlock(canvas, cellRect, paletteColor(colorIndex), cellSize);
      _paintJellyRing(canvas, r, radius, cellSize, 1);

    case Cell.doubleJelly:
      paintBlock(canvas, cellRect, paletteColor(colorIndex), cellSize);
      _paintJellyRing(canvas, r, radius, cellSize, 2);

    case Cell.stone:
      paintBlock(canvas, cellRect, _stoneFill, cellSize);
      _paintCrack(canvas, r, cellSize);

    case Cell.star:
      paintBlock(canvas, cellRect, paletteColor(colorIndex), cellSize);
      _paintStar(canvas, r.center, cellSize * 0.24);
  }
}

/// A five pointed star, sitting on the block that carries it.
///
/// Drawn with a dark rim rather than a plain gold shape: the palette already
/// has a gold in it, and a bare gold star on a gold block would vanish.
void _paintStar(Canvas canvas, Offset centre, double r) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final a = -pi / 2 + i * pi / 5;
    final rr = i.isEven ? r : r * 0.46;
    final p = Offset(centre.dx + cos(a) * rr, centre.dy + sin(a) * rr);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.42
      ..strokeJoin = StrokeJoin.round
      ..color = scrim.withValues(alpha: 0.75),
  );
  canvas.drawPath(path, Paint()..color = textAccent);
  // A highlight on the upper left arm, the same direction the block gloss
  // implies the light is coming from.
  canvas.drawCircle(
    Offset(centre.dx - r * 0.22, centre.dy - r * 0.2),
    r * 0.17,
    Paint()..color = Colors.white.withValues(alpha: 0.65),
  );
}

/// Jelly wears one inner ring, thick jelly wears two.
void _paintJellyRing(
  Canvas canvas,
  Rect r,
  Radius radius,
  double cellSize,
  int rings,
) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.06
    ..color = Colors.white.withValues(alpha: 0.55);
  for (var i = 0; i < rings; i++) {
    final d = r.width * (0.18 + i * 0.14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.deflate(d), radius),
      paint..color = Colors.white.withValues(alpha: 0.55 - i * 0.18),
    );
  }
}

void _paintCrack(Canvas canvas, Rect r, double cellSize) {
  final p = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.055
    ..strokeCap = StrokeCap.round
    ..color = _stoneFillHi;
  final path = Path()
    ..moveTo(r.left + r.width * 0.28, r.top + r.height * 0.72)
    ..lineTo(r.left + r.width * 0.46, r.top + r.height * 0.46)
    ..lineTo(r.left + r.width * 0.38, r.top + r.height * 0.38)
    ..lineTo(r.left + r.width * 0.66, r.top + r.height * 0.22);
  canvas.drawPath(path, p);
}

/// Renders a shape at a fixed cell size. Used by the tray and by the piece
/// that follows the finger.
class PieceView extends StatelessWidget {
  final Shape shape;
  final int colorIndex;
  final double cellSize;
  final double opacity;

  const PieceView({
    super.key,
    required this.shape,
    required this.colorIndex,
    required this.cellSize,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: shape.w * cellSize,
      height: shape.h * cellSize,
      child: CustomPaint(
        painter: _PiecePainter(shape, colorIndex, cellSize, opacity),
      ),
    );
  }
}

class _PiecePainter extends CustomPainter {
  final Shape shape;
  final int colorIndex;
  final double cellSize;
  final double opacity;

  _PiecePainter(this.shape, this.colorIndex, this.cellSize, this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final color = paletteColor(colorIndex);
    for (var i = 0; i < shape.cells.length; i++) {
      final c = shape.cells[i];
      final rect = Rect.fromLTWH(
        (c % shape.w) * cellSize,
        (c ~/ shape.w) * cellSize,
        cellSize,
        cellSize,
      );
      paintBlock(canvas, rect, color, cellSize, opacity: opacity);
    }
  }

  @override
  bool shouldRepaint(_PiecePainter old) =>
      old.shape != shape ||
      old.colorIndex != colorIndex ||
      old.cellSize != cellSize ||
      old.opacity != opacity;
}
