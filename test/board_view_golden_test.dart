import 'package:blocktopus/app/theme.dart';
import 'package:blocktopus/game/board_state.dart';
import 'package:blocktopus/models/piece.dart';
import 'package:blocktopus/widgets/board_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Goldens for the board at three states, section 15. Regenerate with:
///   flutter test --update-goldens test/board_view_golden_test.dart
Widget frame(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    backgroundColor: bg,
    body: Center(
      child: Container(
        width: 320,
        height: 320,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: boardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: child,
      ),
    ),
  ),
);

BoardState midGame() {
  final preset = List<int>.filled(kCellCount, 0);
  // One of each special kind, plus a scatter of ordinary blocks.
  preset[0] = 1; // blocked
  preset[9] = 3; // jelly
  preset[10] = 4; // double jelly
  preset[11] = 5; // stone
  for (final i in <int>[2, 3, 4, 17, 18, 25, 33, 40, 41, 42, 55, 60]) {
    preset[i] = 2;
  }
  return BoardState.fromPreset(preset, 99);
}

void main() {
  testWidgets('empty board', (tester) async {
    await tester.pumpWidget(frame(BoardView(board: BoardState.empty())));
    await expectLater(
      find.byType(BoardView),
      matchesGoldenFile('goldens/board_empty.png'),
    );
  });

  testWidgets('mid game board', (tester) async {
    await tester.pumpWidget(frame(BoardView(board: midGame())));
    await expectLater(
      find.byType(BoardView),
      matchesGoldenFile('goldens/board_mid_game.png'),
    );
  });

  testWidgets('board with a valid ghost', (tester) async {
    final shape = kShapes.firstWhere((s) => s.name == 'l-a');
    await tester.pumpWidget(
      frame(
        BoardView(
          board: midGame(),
          ghost: Ghost(shape: shape, colorIndex: 0, bx: 3, by: 5, valid: true),
        ),
      ),
    );
    await expectLater(
      find.byType(BoardView),
      matchesGoldenFile('goldens/board_ghost.png'),
    );
  });
}
