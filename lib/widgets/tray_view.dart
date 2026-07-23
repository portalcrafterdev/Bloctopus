import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/piece.dart';
import 'piece_view.dart';

/// The three piece slots below the board.
///
/// Dragging is driven from here but resolved by the game screen, which owns
/// the board geometry and the piece that follows the finger.
class TrayView extends StatelessWidget {
  final List<Piece?> tray;
  final int? draggingSlot;
  final bool enabled;

  final void Function(int slot, Offset globalPosition) onDragStart;
  final void Function(Offset globalPosition) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;

  /// Pieces that no longer fit anywhere are dimmed, so a dead end is readable
  /// before the game over sheet appears.
  final Set<int> unplayableSlots;

  const TrayView({
    super.key,
    required this.tray,
    required this.draggingSlot,
    required this.enabled,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    this.unplayableSlots = const <int>{},
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth / 3;
        // The cell is sized off the largest shape in the library, not off each
        // piece, so relative sizes stay honest. Nothing is wider or taller than
        // five cells, and the row has to be tall enough for the tall ones.
        final cell = (slotWidth - 16) / 5.2;
        return SizedBox(
          height: cell * 5 + 12,
          child: Row(
            children: List<Widget>.generate(3, (slot) {
              final piece = tray[slot];
              final hidden = draggingSlot == slot;
              return SizedBox(
                width: slotWidth,
                child: piece == null
                    ? const SizedBox.shrink()
                    : _Slot(
                        piece: piece,
                        cellSize: cell,
                        enabled: enabled,
                        // The slot being dragged is made invisible rather than
                        // removed. Removing it takes the GestureDetector that
                        // owns the live gesture out of the tree, so the drag
                        // never receives another update or an end, and the
                        // piece sticks to the screen for good.
                        hidden: hidden,
                        dimmed: unplayableSlots.contains(slot),
                        onStart: (g) => onDragStart(slot, g),
                        onUpdate: onDragUpdate,
                        onEnd: onDragEnd,
                        onCancel: onDragCancel,
                      ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  final Piece piece;
  final double cellSize;
  final bool enabled;
  final bool hidden;
  final bool dimmed;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  const _Slot({
    required this.piece,
    required this.cellSize,
    required this.enabled,
    required this.hidden,
    required this.dimmed,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: enabled ? (d) => onStart(d.globalPosition) : null,
      onPanUpdate: enabled ? (d) => onUpdate(d.globalPosition) : null,
      onPanEnd: enabled ? (_) => onEnd() : null,
      onPanCancel: enabled ? onCancel : null,
      child: Center(
        child: Opacity(
          opacity: hidden ? 0 : (dimmed ? 0.32 : 1),
          child: PieceView(
            shape: piece.shape,
            colorIndex: piece.colorIndex,
            cellSize: cellSize,
          ),
        ),
      ),
    );
  }
}

/// The panel the tray sits in.
class TrayPanel extends StatelessWidget {
  final Widget child;

  const TrayPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: boardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}
