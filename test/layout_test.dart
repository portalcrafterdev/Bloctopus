import 'package:blocktopus/game/level_loader.dart';
import 'package:blocktopus/models/level.dart';
import 'package:blocktopus/models/save_data.dart';
import 'package:blocktopus/screens/game_screen.dart';
import 'package:blocktopus/screens/home_screen.dart';
import 'package:blocktopus/screens/map_screen.dart';
import 'package:blocktopus/screens/result_screen.dart';
import 'package:blocktopus/screens/settings_screen.dart';
import 'package:blocktopus/widgets/board_view.dart';
import 'package:blocktopus/widgets/mascot_view.dart';
import 'package:blocktopus/widgets/tray_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layout regressions are the easy way to ship a broken build: an overflow
/// only shows up on the one device that is narrower than the one you tested.
/// The widget tester turns overflows into test failures, so pumping each
/// screen at the smallest sizes we support is the whole test.
const List<Size> _sizes = <Size>[
  Size(320, 568), // iPhone SE, first generation
  Size(360, 640), // the low end Android floor
  Size(412, 915), // a common modern Android
  Size(430, 932), // iPhone Pro Max
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    LevelLoader.instance.debugReset();
  });

  for (final size in _sizes) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('game screen lays out at $label', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Unmount before teardown so timers and tickers get disposed.
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final save = await SaveData.load();
      await tester.runAsync(() => LevelLoader.instance.load(1));
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(levelId: 1, save: save)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BoardView), findsOneWidget);
      expect(find.byType(TrayView), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The board must stay square and inside the viewport.
      final board = tester.getRect(find.byType(BoardView));
      expect(board.width, closeTo(board.height, 1));
      expect(board.width, greaterThan(0));
      expect(board.right, lessThanOrEqualTo(size.width + 0.5));
    });

    testWidgets('home screen lays out at $label', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Unmount before teardown so timers and tickers get disposed.
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final save = await SaveData.load();
      await tester.pumpWidget(MaterialApp(home: HomeScreen(save: save)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Levels'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the pause menu lays out at $label', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final save = await SaveData.load();
      await tester.runAsync(() => LevelLoader.instance.load(1));
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(levelId: 1, save: save)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Dismiss the chapter tutorial, then pause. Four buttons and the mascot
      // are taller than a 320x568 screen, so this is where the menu overflows
      // if it ever stops scrolling.
      await tester.tapAt(Offset(size.width / 2, 60));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Paused'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('map screen lays out at $label', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Unmount before teardown so timers and tickers get disposed.
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final save = await SaveData.load();
      await tester.pumpWidget(MaterialApp(home: MapScreen(save: save)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Blocktopus'), findsOneWidget);
      expect(find.text('Tide Pools'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings screen lays out at $label', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Unmount before teardown so timers and tickers get disposed.
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final save = await SaveData.load();
      await tester.pumpWidget(MaterialApp(home: SettingsScreen(save: save)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Reduce motion'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the map opens on the player current level', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final save = await SaveData.load();
    save.currentLevel = 137; // chapter 2
    await tester.pumpWidget(MaterialApp(home: MapScreen(save: save)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('137'), findsOneWidget);
    expect(find.text('1'), findsNothing, reason: 'chapter 1 is far above');
  });

  testWidgets('the mascot paints in every state', (tester) async {
    for (final state in MascotState.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: MascotView(size: 120, state: state)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull, reason: 'state $state');
    }
  });

  testWidgets('the mascot survives being laid out at zero size', (
    tester,
  ) async {
    // He used to throw "Bad state: No element" here, not overflow: at zero
    // size every arm curve collapses to a point, and a zero length path has no
    // metrics to hang the suckers off. Any parent that sizes him from a value
    // that has not arrived yet took the whole frame down with it.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: MascotView(size: 0, state: MascotState.idle)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the mascot tracks a look target without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: MascotView(
              size: 90,
              state: MascotState.watching,
              lookAt: Offset(200, -40),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.takeException(), isNull);
  });

  // The screens above are the ones a player sees first, so they were the ones
  // that got sized. Everything below is a state the player only reaches after
  // playing, which is exactly why an overflow can survive in it.

  for (final size in _sizes) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    for (final won in <bool>[true, false]) {
      final what = won ? 'win' : 'loss';
      testWidgets('the $what result sheet lays out at $label', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

        final save = await SaveData.load();
        final level = await _level(tester, 25); // a boss, the widest banner
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ResultSheet(
                level: level,
                save: save,
                result: LevelResult(
                  won: won,
                  stars: won ? 3 : 0,
                  score: 128400, // a long number, so the row is at its widest
                  movesUsed: 34,
                  linesCleared: 12,
                  boosterAwarded: won ? BoosterId.hammer : null,
                ),
              ),
            ),
          ),
        );
        // Past the 220ms-per-star reveal, so all three stars are on screen.
        await tester.pump(const Duration(milliseconds: 900));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the tutorial overlay lays out at $label', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final save = await SaveData.load();
      await tester.runAsync(() => LevelLoader.instance.load(1));
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(levelId: 1, save: save)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Level 1 is a chapter opener and the save is fresh, so the mascot's
      // tutorial is showing over the board.
      expect(find.byType(MascotView), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('blast targeting mode lays out at $label', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final save = await SaveData.load();
      await tester.runAsync(() => LevelLoader.instance.load(1));
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(levelId: 1, save: save)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Dismiss the tutorial, then arm Ink blast: the cancel row and the
      // reaching arm only exist in this state.
      await tester.tapAt(Offset(size.width / 2, size.height * 0.9));
      await tester.pump(const Duration(milliseconds: 100));
      final blast = find.text('Ink blast');
      if (blast.evaluate().isNotEmpty) {
        await tester.tap(blast, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(tester.takeException(), isNull);
    });
  }

  // A player who has turned the system font up is still a player. Flutter
  // scales every label but not the boxes around them, so this is where text
  // rows overflow first, and none of the sizes above would catch it.
  for (final scale in <double>[1.3, 1.6]) {
    testWidgets('the game screen survives text scale $scale', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final save = await SaveData.load();
      await tester.runAsync(() => LevelLoader.instance.load(1));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: GameScreen(levelId: 1, save: save),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the home screen survives text scale $scale', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final save = await SaveData.load();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: HomeScreen(save: save),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the map screen survives text scale $scale', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final save = await SaveData.load();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: MapScreen(save: save),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the settings screen survives text scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final save = await SaveData.load();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: SettingsScreen(save: save),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  }
}

Future<Level> _level(WidgetTester tester, int id) async {
  late Level level;
  await tester.runAsync(() async {
    level = await LevelLoader.instance.load(id);
  });
  return level;
}
