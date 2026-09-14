import 'package:blocktopus/models/save_data.dart';
import 'package:blocktopus/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The tiles that fill the home screen below the play keys.
///
/// They all read straight off the save, so the risk is not that they show the
/// wrong number - it is that they lay out wrong and nobody notices. That is a
/// real gap rather than a hypothetical one: `layout_test.dart` pumps this
/// screen at four sizes and two text scales, but always with a *fresh* save,
/// so the chapter card and the stat tiles never rendered in any of those runs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  SaveData midGame() => SaveData(
    currentLevel: 102,
    stars: <int, int>{for (var i = 1; i <= 101; i++) i: i % 4 == 0 ? 3 : 2},
    boosters: <String, int>{
      BoosterId.undo: 3,
      BoosterId.hammer: 2,
      BoosterId.refresh: 4,
    },
    totalScore: 128400,
    levelsCompleted: 101,
  );

  Future<void> pump(
    WidgetTester tester,
    SaveData save, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: HomeScreen(save: save),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('the progress bar spans its card', (tester) async {
    // The trap this exists for: a Column centres its children, which hands
    // them loose width constraints, so a bar that sized to its own fill would
    // draw a 5% pill floating mid-card with no track behind it. It reads as a
    // deliberate decoration, which is why only a screenshot would catch it.
    await pump(tester, midGame());

    final bar = tester.getSize(find.byKey(const Key('home-progress')));
    // 390 wide, less 22 of screen padding each side, capped at the play keys'
    // 300, less the card's 1px border and 14 of padding each side.
    expect(
      bar.width,
      closeTo(300 - 2 - 28, 1),
      reason: 'the bar collapsed to the width of its own fill',
    );
    expect(bar.height, 9);
  });

  testWidgets('the chapter card names where the player is', (tester) async {
    // Level 102 is the second level of chapter 2. The number alone says
    // nothing; the name is the half worth showing.
    await pump(tester, midGame());
    expect(find.text('Chapter 2 · Kelp Forest'), findsOneWidget);
    expect(find.text('102 / 2000'), findsOneWidget);
  });

  testWidgets('the stat tiles show what the save holds', (tester) async {
    await pump(tester, midGame());
    expect(find.text('101'), findsOneWidget); // levels cleared
    expect(find.text('227'), findsOneWidget); // stars: 25 threes, 76 twos
    expect(find.text('128k'), findsOneWidget); // score, shortened
    for (final label in <String>['Cleared', 'Stars', 'Score']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('the booster counts are not repeated here', (tester) async {
    // They were tiles on this screen for a while and the owner took them out.
    // The booster bar under the tray already carries these three, where they
    // are a control rather than a readout, so a second copy on the home screen
    // was a number with nothing to do.
    await pump(tester, midGame());
    for (final label in <String>['Rewind', 'Ink blast', 'Reshuffle']) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('a fresh save keeps the chapter card and drops the stats', (
    tester,
  ) async {
    // The chapter card earns its place before the first level: it says where
    // the player is about to go. The stat tiles do not - three zeroes tell a
    // new player only that they have done nothing, which they know.
    await pump(tester, SaveData());
    expect(find.text('Chapter 1 · Tide Pools'), findsOneWidget);
    expect(find.byKey(const Key('home-progress')), findsOneWidget);
    expect(find.text('Cleared'), findsNothing);
    expect(find.text('Stars'), findsNothing);
    expect(find.text('Levels'), findsOneWidget); // the key, not a stat tile
  });

  testWidgets('the score tile shortens only once it has to', (tester) async {
    await pump(tester, midGame()..totalScore = 9999);
    expect(find.text('9999'), findsOneWidget);
  });

  // The gap `layout_test.dart` leaves: every one of its home screen runs uses
  // a fresh save, so nothing there has ever laid out a chapter card or a stat
  // tile. These are the sizes and scales where three tiles in a row break.
  for (final size in <Size>[const Size(320, 568), const Size(360, 640)]) {
    for (final scale in <double>[1, 1.6]) {
      testWidgets(
        'a mid-game home lays out at ${size.width.toInt()}x'
        '${size.height.toInt()} at text scale $scale',
        (tester) async {
          await pump(tester, midGame(), size: size, textScale: scale);
          expect(tester.takeException(), isNull);

          final bar = tester.getRect(find.byKey(const Key('home-progress')));
          expect(bar.left, greaterThanOrEqualTo(0));
          expect(bar.right, lessThanOrEqualTo(size.width + 0.5));
        },
      );
    }
  }
}
