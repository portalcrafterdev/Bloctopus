import 'package:blocktopus/widgets/game_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The outlined heading style.
///
/// The point of these is that the effect costs several draws but exactly one
/// widget. Stacking the passes as widgets was the obvious build and the wrong
/// one: it put the same string in the tree four times, so a screen reader read
/// every heading four times over and `find.text` matched four candidates for
/// one visible word - which is how it was caught, by breaking the map layout
/// test.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, {double w = 300}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: w, child: child))),
      ),
    );
    await tester.pump();
  }

  testWidgets('puts the string in the tree exactly once', (tester) async {
    await pump(tester, const GameText('Tide Pools'));
    expect(find.text('Tide Pools'), findsOneWidget);
  });

  testWidgets('reads once to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const GameText('Level complete'));
    expect(
      find.bySemanticsLabel('Level complete'),
      findsOneWidget,
      reason: 'a heading announced more than once is a heading read twice',
    );
    handle.dispose();
  });

  testWidgets('a flat single colour still renders one Text', (tester) async {
    await pump(
      tester,
      const GameText('Solid', colors: <Color>[Color(0xFFFFC24D)]),
    );
    expect(find.text('Solid'), findsOneWidget);
  });

  testWidgets('honours maxLines and ellipsis', (tester) async {
    // The map banner sits in a fixed height band, so a chapter name that
    // wrapped would push the panel through the bottom of it.
    await pump(
      tester,
      const GameText(
        'A chapter name far too long for one line',
        fontSize: 26,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      w: 200,
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(Text).first,
    );
    expect(paragraph.maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow its box', (tester) async {
    // The stroke is drawn outside the glyphs, so the painter draws wider than
    // the text it backs. It must not make the widget itself bigger.
    await pump(tester, const GameText('Tide Pools', fontSize: 40));
    final textSize = tester.getSize(find.text('Tide Pools'));
    final paintSize = tester.getSize(find.byType(CustomPaint).last);
    expect(
      paintSize,
      textSize,
      reason: 'the painter is sized by its child, so the two must agree',
    );
  });
}
