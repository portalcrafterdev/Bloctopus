import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/board_state.dart';
import '../models/piece.dart';
import 'piece_view.dart';

/// The placement preview under the finger.
class Ghost {
  final Shape shape;
  final int colorIndex;
  final int bx;
  final int by;
  final bool valid;

  const Ghost({
    required this.shape,
    required this.colorIndex,
    required this.bx,
    required this.by,
    required this.valid,
  });
}

class BoardView extends StatelessWidget {
  final BoardState board;
  final Ghost? ghost;

  /// Ink Blast targeting: the board dims and blastable cells highlight.
  final bool blastMode;
  final ValueChanged<int>? onCellTap;

  /// Cells currently mid clear animation, drawn dimmer.
  final Set<int> clearing;

  const BoardView({
    super.key,
    required this.board,
    this.ghost,
    this.blastMode = false,
    this.onCellTap,
    this.clearing = const <int>{},
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final cell = side / kBoardSize;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onCellTap == null
              ? null
              : (d) {
                  final x = (d.localPosition.dx / cell).floor();
                  final y = (d.localPosition.dy / cell).floor();
                  if (x < 0 || y < 0 || x >= kBoardSize || y >= kBoardSize) {
                    return;
                  }
                  onCellTap!(y * kBoardSize + x);
                },
          child: SizedBox(
            width: side,
            height: side,
            child: CustomPaint(
              painter: _BoardPainter(
                board: board,
                ghost: ghost,
                blastMode: blastMode,
                clearing: clearing,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  final BoardState board;
  final Ghost? ghost;
  final bool blastMode;
  final Set<int> clearing;

  _BoardPainter({
    required this.board,
    required this.ghost,
    required this.blastMode,
    required this.clearing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.shortestSide / kBoardSize;

    for (var y = 0; y < kBoardSize; y++) {
      for (var x = 0; x < kBoardSize; x++) {
        final i = y * kBoardSize + x;
        final rect = Rect.fromLTWH(x * cell, y * cell, cell, cell);
        paintCell(
          canvas,
          rect,
          cell,
          board.kinds[i],
          board.colors[i],
          altSquare: (x + y).isOdd,
        );
      }
    }

    if (blastMode) {
      // Dim the board, then lift the cells the player may hit.
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = scrim.withValues(alpha: 0.55),
      );
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = inkPink.withValues(alpha: 0.9);
      for (var i = 0; i < kCellCount; i++) {
        if (!Cell.blastable(board.kinds[i])) continue;
        final x = i % kBoardSize;
        final y = i ~/ kBoardSize;
        final rect = Rect.fromLTWH(
          x * cell,
          y * cell,
          cell,
          cell,
        ).deflate(cell * kCellInsetFactor);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(cell * kCellRadiusFactor),
          ),
          glow,
        );
      }
    }

    final g = ghost;
    if (g != null) {
      final color = g.valid ? paletteColor(g.colorIndex) : ghostInvalid;
      final fill = Paint()
        ..color = color.withValues(alpha: g.valid ? 0.34 : 0.22);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color;

      for (var i = 0; i < g.shape.cells.length; i++) {
        final c = g.shape.cells[i];
        final x = g.bx + c % g.shape.w;
        final y = g.by + c ~/ g.shape.w;
        if (x < 0 || y < 0 || x >= kBoardSize || y >= kBoardSize) continue;
        final rect = Rect.fromLTWH(
          x * cell,
          y * cell,
          cell,
          cell,
        ).deflate(cell * kCellInsetFactor);
        final rr = RRect.fromRectAndRadius(
          rect,
          Radius.circular(cell * kCellRadiusFactor),
        );
        canvas.drawRRect(rr, fill);
        canvas.drawRRect(rr, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}
