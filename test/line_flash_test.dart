import 'package:blocktopus/app/theme.dart';
import 'package:blocktopus/widgets/line_flash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// When a line completes it lights up in the colour of the piece that closed
/// it, holds for a beat, and only then breaks apart. The board itself has
/// already cleared - `board_state.dart` is pure and instant - so this layer is
/// painting over cells that are logically empty, and the timing has to be
/// right or the clear reads as the board acting on its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Rect> row(int y, double cell) => <Rect>[
    for (var x = 0; x < 8; x++) Rect.fromLTWH(x * cell, y * cell, cell, cell),
  ];

  group('line flash', () {
    test('holds solid before it starts fading', () {
      final c = LineFlashController();
      c.flash(row(3, 40), palette.first, 40);
      expect(c.isEmpty, isFalse);

      for (var i = 0; i < kFlashHoldFrames; i++) {
        expect(c.flashes.single.opacity, 1, reason: 'frame $i should be solid');
        c.tick();
      }
      // Now fading.
      c.tick();
      expect(c.flashes.single.opacity, lessThan(1));
    });

    test('clears itself, so the board is never left painted over', () {
      final c = LineFlashController()..flash(row(0, 40), palette.first, 40);
      for (var i = 0; i < kFlashHoldFrames + kFlashFadeFrames + 2; i++) {
        c.tick();
      }
      expect(c.isEmpty, isTrue);
    });

    test('the break fires once, when the fade starts, not on placement', () {
      var breaks = 0;
      final c = LineFlashController();
      c.flash(row(1, 40), palette.first, 40, onBreak: () => breaks++);

      // Nothing bursts while the line is still lit.
      expect(breaks, 0);
      for (var i = 0; i < kFlashHoldFrames - 1; i++) {
        c.tick();
      }
      expect(breaks, 0, reason: 'the line is still holding');

      c.tick();
      expect(breaks, 1, reason: 'the line should break as it starts to fade');

      // And never again, however long it runs.
      for (var i = 0; i < 40; i++) {
        c.tick();
      }
      expect(breaks, 1);
    });

    test('an undone placement never bursts', () {
      // Rewind drops the flash mid-flight. If the callback still ran, the
      // player would see particles for a clear that had been taken back.
      var breaks = 0;
      final c = LineFlashController();
      c.flash(row(2, 40), palette.first, 40, onBreak: () => breaks++);
      c.tick();
      c.clear();

      for (var i = 0; i < 40; i++) {
        c.tick();
      }
      expect(breaks, 0);
      expect(c.isEmpty, isTrue);
    });

    test(
      'an empty clear still reports the break, so nothing is left waiting',
      () {
        var breaks = 0;
        LineFlashController().flash(
          <Rect>[],
          palette.first,
          40,
          onBreak: () => breaks++,
        );
        expect(breaks, 1);
      },
    );

    test('several lines at once each run their own flash', () {
      final c = LineFlashController()
        ..flash(row(0, 40), palette.first, 40)
        ..flash(row(1, 40), palette[1], 40);
      expect(c.flashes.length, 2);
    });

    testWidgets('paints through a single painter and stops on its own', (
      tester,
    ) async {
      final c = LineFlashController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: bg,
            body: SizedBox(
              width: 320,
              height: 320,
              child: LineFlashLayer(controller: c),
            ),
          ),
        ),
      );

      c.flash(row(4, 40), palette.first, 40);
      await tester.pump(const Duration(milliseconds: 16));

      final painters = find.descendant(
        of: find.byType(LineFlashLayer),
        matching: find.byType(CustomPaint),
      );
      expect(tester.widgetList(painters).length, 1);

      // Past the whole animation: it must have drained without a timer.
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(c.isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
