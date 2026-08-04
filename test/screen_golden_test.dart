import 'package:blocktopus/app/theme.dart';
import 'package:blocktopus/game/board_state.dart';
import 'package:blocktopus/game/level_loader.dart';
import 'package:blocktopus/widgets/blast_hammer.dart';
import 'package:blocktopus/widgets/board_view.dart';
import 'package:blocktopus/models/save_data.dart';
import 'package:blocktopus/widgets/combo_text.dart';
import 'package:blocktopus/widgets/line_flash.dart';
import 'package:blocktopus/screens/game_screen.dart';
import 'package:blocktopus/screens/home_screen.dart';
import 'package:blocktopus/screens/map_screen.dart';
import 'package:blocktopus/screens/result_screen.dart';
import 'package:blocktopus/screens/settings_screen.dart';
import 'package:blocktopus/models/level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whole screen goldens, at one common phone size. These are what the game
/// actually looks like, and they fail loudly when a layout or a colour drifts.
///
///   flutter test --update-goldens test/screen_golden_test.dart
///
/// The mascot animates, so every case pumps a fixed duration to land on a
/// deterministic frame.
const Size _phone = Size(412, 915);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    LevelLoader.instance.debugReset();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('home screen', (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    final save = await SaveData.load();
    save.currentLevel = 47;
    save.levelsCompleted = 46;
    save.stars.addAll(<int, int>{for (var i = 1; i <= 46; i++) i: 2});
    await tester.pumpWidget(MaterialApp(home: HomeScreen(save: save)));
    await settle(tester);

    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/screen_home.png'),
    );
  });

  testWidgets('game screen paused', (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    final save = await SaveData.load();
    await tester.runAsync(() => LevelLoader.instance.load(1));
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(levelId: 1, save: save)),
    );
    await settle(tester);

    // Dismiss the chapter 1 tutorial, then pause.
    await tester.tapAt(const Offset(206, 60));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await settle(tester);

    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/screen_paused.png'),
    );
  });

  testWidgets('game screen', (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    final save = await SaveData.load();
    await tester.runAsync(() => LevelLoader.instance.load(1));
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(levelId: 1, save: save)),
    );
    await settle(tester);

    // Dismiss the chapter 1 tutorial overlay so the board is visible.
    await tester.tapAt(const Offset(206, 60));
    await settle(tester);

    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/screen_game.png'),
    );
  });

  testWidgets('the clear callouts over a lit line', (tester) async {
    // The two things a clear puts on screen: the line lit in the colour of
    // the piece that closed it, and the callouts over the top. Both are
    // painted, so a golden is the only thing that can catch them drifting.
    await tester.binding.setSurfaceSize(const Size(360, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    final flash = LineFlashController();
    final combo = ComboTextController();
    const cell = 40.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: cellEmpty,
          body: Stack(
            children: [
              LineFlashLayer(controller: flash),
              ComboTextLayer(controller: combo),
            ],
          ),
        ),
      ),
    );

    flash.flash(
      <Rect>[
        for (var x = 0; x < 8; x++)
          Rect.fromLTWH(x * cell, 4 * cell, cell, cell),
      ],
      paletteColor(3),
      cell,
    );
    combo.showClear(const Offset(180, 210), 2, 40);
    combo.showStreak(const Offset(180, 210), 2); // "Combo"

    // Far enough in for the word to have finished its pop, early enough that
    // the line is still lit.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(Stack).first,
      matchesGoldenFile('goldens/clear_callout.png'),
    );
  });

  testWidgets('game screen with the tutorial overlay', (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    final save = await SaveData.load();
    await tester.runAsync(() => LevelLoader.instance.load(1));
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(levelId: 1, save: save)),
    );
    await settle(tester);

    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/screen_tutorial.png'),
    );
  });

  testWidgets('the ink blast hammer mid swing', (tester) async {
    // The swing is entirely painted, so a golden is the only thing that can
    // catch the hammer drifting off its cell or coming apart.
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    final save = await SaveData.load();
    await tester.runAsync(() => LevelLoader.instance.load(1));
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(levelId: 1, save: save)),
    );
    await settle(tester);
    await tester.tapAt(const Offset(206, 60)); // dismiss the tutorial
    await settle(tester);

    await tester.tap(find.text('Ink blast'));
    await tester.pump(const Duration(milliseconds: 100));

    // Armed but not yet aimed: the hammer waits at the edge of the board.
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/screen_blast_ready.png'),
    );

    // Aim at the first filled cell.
    final level = await LevelLoader.instance.load(1);
    final start = BoardState.fromPreset(level.preset, level.seed);
    final index = <int>[
      for (var i = 0; i < kCellCount; i++)
        if (Cell.blastable(start.kinds[i])) i,
    ].first;
    final board = tester.getRect(find.byType(BoardView));
    final cell = board.width / kBoardSize;
    await tester.tapAt(
      Offset(
        board.left + (index % kBoardSize + 0.5) * cell,
        board.top + (index ~/ kBoardSize + 0.5) * cell,
      ),
    );
    // One frame to build the hammer and start its controller: `pump(d)` moves
    // the clock and *then* builds, so a single big pump would leave the swing
    // still at zero, parked off screen waiting to fly in.
    await tester.pump();
    expect(find.byType(BlastHammer), findsOneWidget, reason: 'no swing');
    // Just before the head lands, so the hammer is at full stretch over the
    // block it is about to break.
    await tester.pump(BlastHammer.duration * (BlastHammer.impactAt - 0.06));

    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/screen_blast.png'),
    );

    // No golden for the frame after impact: the shards fly on random
    // velocities, so it would fail on its own output. `particle_test.dart`
    // checks what a shattered block actually produces instead.
  });

  testWidgets('map screen', (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    final save = await SaveData.load();
    save.currentLevel = 6;
    for (var i = 1; i <= 5; i++) {
      save.stars[i] = i % 3 + 1;
    }
    await tester.pumpWidget(MaterialApp(home: MapScreen(save: save)));
    await settle(tester);

    await expectLater(
      find.byType(MapScreen),
      matchesGoldenFile('goldens/screen_map.png'),
    );
  });

  testWidgets('result sheet', (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    final save = await SaveData.load();
    final level = await tester.runAsync(() => LevelLoader.instance.load(1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF141026),
          body: ResultSheet(
            level: level!,
            result: const LevelResult(
              won: true,
              stars: 3,
              score: 168,
              movesUsed: 11,
              linesCleared: 6,
              boosterAwarded: 'hammer',
            ),
            save: save,
          ),
        ),
      ),
    );
    await settle(tester);
    await settle(tester);

    await expectLater(
      find.byType(ResultSheet),
      matchesGoldenFile('goldens/screen_result.png'),
    );
  });

  testWidgets('settings screen', (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    final save = await SaveData.load();
    save.levelsCompleted = 46;
    save.totalScore = 128400;
    save.stars.addAll(<int, int>{for (var i = 1; i <= 46; i++) i: 2});
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(save: save)));
    await settle(tester);

    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/screen_settings.png'),
    );
  });
}
