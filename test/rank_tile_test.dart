import 'dart:io';

import 'package:blocktopus/app/theme.dart';
import 'package:blocktopus/games/games_service.dart';
import 'package:blocktopus/models/save_data.dart';
import 'package:blocktopus/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The player's leaderboard position, shown beside the stats it is derived
/// from.
///
/// The interesting half is when it is *not* shown. A rank is the only number
/// on that row that does not come off the save, so it can be absent for
/// reasons none of the others have: signed out, offline, or signed in with no
/// score on the board yet, which is everyone until their first level lands.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GamesService.instance.debugReset();
  });
  tearDown(() => GamesService.instance.debugReset());

  Future<SaveData> pumpHome(WidgetTester tester, {double width = 390}) async {
    final save = SaveData(
      currentLevel: 10,
      levelsCompleted: 9,
      totalScore: 5000,
    );
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(save: save)));
    await tester.pump();
    return save;
  }

  testWidgets('no rank is shown when there is no position to show', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Rank'), findsNothing);
    // The three that come off the save are unaffected by any of this.
    expect(find.text('Cleared'), findsOneWidget);
    expect(find.text('Score'), findsOneWidget);
  });

  testWidgets('a known position appears beside the other stats', (
    tester,
  ) async {
    await pumpHome(tester);
    GamesService.instance.rank.value = 1204;
    await tester.pump();

    expect(find.text('Rank'), findsOneWidget);
    expect(find.text('#1204'), findsOneWidget);
  });

  testWidgets('disconnecting takes the rank with it', (tester) async {
    // It belonged to the account. Left on screen after the account has gone it
    // would be the one number up there referring to nothing.
    await pumpHome(tester);
    GamesService.instance.player.value = const GamesPlayer(name: 'Reef');
    GamesService.instance.rank.value = 1204;
    await tester.pump();
    expect(find.text('Rank'), findsOneWidget);

    await GamesService.instance.disconnect();
    await tester.pump();

    expect(find.text('Rank'), findsNothing);
  });

  testWidgets('four stats still fit on a narrow phone', (tester) async {
    // Three tiles had 84pt of width each; a fourth cuts that to 67. This is
    // the assertion that a rank tile cannot quietly push the row over the
    // edge - a RenderFlex overflow throws into the binding.
    await pumpHome(tester, width: 320);
    GamesService.instance.rank.value = 999999;
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Rank'), findsOneWidget);
  });

  testWidgets('no stat label is ellipsized at 320pt', (tester) async {
    // The real font, loaded, and that is not a detail. The default test font
    // draws every glyph a full em wide, which makes "Cleared" 79pt at 11pt -
    // wider than its tile in the *existing* three-up row, so measured against
    // that font this asserts a truncation the shipped build does not have.
    // Bagel Fat One is a display face but nothing like an em per glyph.
    await tester.runAsync(() async {
      final loader = FontLoader(kDisplayFont)
        ..addFont(
          File(
            'assets/fonts/BagelFatOne-Regular.ttf',
          ).readAsBytes().then((b) => b.buffer.asByteData()),
        );
      await loader.load();
    });

    await pumpHome(tester, width: 320);
    GamesService.instance.rank.value = 1204;
    await tester.pump();

    for (final label in <String>['Cleared', 'Stars', 'Score', 'Rank']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '"$label" is truncated once a fourth tile is on the row',
      );
    }
  });

  test('a rank the board does not have is not invented', () async {
    // Play Games reports "no placing" as a rank of zero, and one-based ranks
    // mean zero is not first place. Showing it would read as the top of the
    // board to the one player who is not on it at all.
    GamesService.instance.player.value = const GamesPlayer(name: 'Reef');
    GamesService.instance.debugLoadRank = () async => 0;

    await GamesService.instance.refreshRank();

    expect(GamesService.instance.rank.value, isNull);
  });

  test('no rank is fetched while signed out', () async {
    var called = false;
    GamesService.instance.debugLoadRank = () async {
      called = true;
      return 7;
    };

    await GamesService.instance.refreshRank();

    expect(called, isFalse, reason: 'asked the board about nobody');
    expect(GamesService.instance.rank.value, isNull);
  });
}
