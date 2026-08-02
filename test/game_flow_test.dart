import 'package:blocktopus/app/theme.dart';
import 'package:blocktopus/game/board_state.dart';
import 'package:blocktopus/game/game_controller.dart';
import 'package:blocktopus/game/level_loader.dart';
import 'package:blocktopus/game/solver.dart';
import 'package:blocktopus/models/level.dart';
import 'package:blocktopus/models/piece.dart';
import 'package:blocktopus/models/save_data.dart';
import 'package:blocktopus/screens/game_screen.dart';
import 'package:blocktopus/screens/home_screen.dart';
import 'package:blocktopus/screens/map_screen.dart';
import 'package:blocktopus/widgets/blast_hammer.dart';
import 'package:blocktopus/widgets/board_view.dart';
import 'package:blocktopus/widgets/goal_banner.dart';
import 'package:blocktopus/widgets/tray_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The chapter parameters live with the generator that used them, so the tests
// re-check levels against the same numbers rather than a second copy.
import '../tool/generate_levels.dart' show paramsFor;

Level testLevel({
  GoalType goal = GoalType.clearLines,
  int target = 1,
  int moveLimit = 0,
  List<int>? preset,
}) => Level(
  id: 1,
  chapter: 1,
  goal: goal,
  target: target,
  moveLimit: moveLimit,
  preset: preset ?? List<int>.filled(kCellCount, 0),
  shapePool: const <int>[0, 1, 2, 9],
  seed: 4242,
  starTargets: const <int>[10, 40, 80],
);

/// The score, read out of the header rather than off any Text on screen.
int scoreInHeader(WidgetTester tester) {
  final texts = find.descendant(
    of: find.byType(ScoreHeader),
    matching: find.byType(Text),
  );
  for (final w in tester.widgetList<Text>(texts)) {
    final data = w.data;
    if (data == null || data.startsWith('Level')) continue;
    final n = int.tryParse(data);
    if (n != null) return n;
  }
  fail('no score found in the header');
}

/// Drags tray slot 0 onto the first square its piece legally fits in, using the
/// same maths the game screen uses to decide where the piece landed.
///
/// Aiming at the board centre looks reasonable and is wrong: level 1 has preset
/// blocks there, so the ghost would be invalid and nothing would land, which
/// makes "the score did not change" prove nothing.
Future<void> dragFirstPieceOntoBoard(WidgetTester tester) async {
  final board = tester.getRect(find.byType(BoardView));
  final cell = board.width / kBoardSize;
  final tray = tester.getRect(find.byType(TrayView));

  final level = await LevelLoader.instance.load(1);
  final piece = PieceSequence(level.seed, level.shapePool).at(0);
  final start = BoardState.fromPreset(level.preset, level.seed);
  final (bx, by) = start.placementsFor(piece.shape).first;

  // Invert the drag maths from the game screen: the piece renders at board
  // cell size, centred on the touch point and 1.4 cells above it.
  final pieceCentre = Offset(
    board.left + (bx + piece.shape.w / 2) * cell,
    board.top + (by + piece.shape.h / 2) * cell,
  );
  final from = Offset(tray.left + tray.width / 6, tray.center.dy);
  final to = pieceCentre + Offset(0, cell * kDragLiftFactor);

  final gesture = await tester.startGesture(from);
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.moveTo(to);
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Puts a fresh level 1 on screen with its chapter tutorial dismissed.
Future<SaveData> pumpLevelOne(WidgetTester tester, {Size? size}) async {
  await tester.binding.setSurfaceSize(size ?? const Size(412, 915));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // Unmount before teardown so tickers and timers get disposed.
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  final save = await SaveData.load();
  // Warm the level cache on the real event loop: the screen's own load is
  // async and a fake-time pump will not wait for asset I/O.
  await tester.runAsync(() => LevelLoader.instance.load(1));
  await tester.pumpWidget(
    MaterialApp(home: GameScreen(levelId: 1, save: save)),
  );
  await tester.pump(const Duration(milliseconds: 100));

  // Level 1 opens chapter 1, so the mascot's tutorial overlay is up and
  // absorbs every pointer until it is dismissed.
  expect(find.text('Tap to start'), findsOneWidget);
  await tester.tapAt(Offset((size ?? const Size(412, 915)).width / 2, 60));
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('Tap to start'), findsNothing);
  return save;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    LevelLoader.instance.debugReset();
  });

  group('GameController', () {
    test('places a piece and consumes the tray slot', () async {
      final save = await SaveData.load();
      final g = GameController(level: testLevel(), save: save);
      final piece = g.tray[0]!;
      expect(g.place(0, 0, 0), isTrue);
      expect(g.tray[0], isNull);
      expect(g.score, piece.shape.size);
      expect(g.movesUsed, 1);
    });

    test('the tray refills only when all three slots are empty', () async {
      final save = await SaveData.load();
      // Dots only, so every placement is trivially legal.
      final level = Level(
        id: 1,
        chapter: 1,
        goal: GoalType.reachScore,
        target: 9999,
        moveLimit: 0,
        preset: List<int>.filled(kCellCount, 0),
        shapePool: const <int>[0],
        seed: 7,
        starTargets: const <int>[1, 2, 3],
      );
      final g = GameController(level: level, save: save);
      final firstSeq = g.tray[2]!.seqIndex;

      g.place(0, 0, 0);
      expect(g.tray[1], isNotNull, reason: 'no refill after one placement');
      g.place(1, 2, 0);
      expect(g.tray[0], isNull, reason: 'still not refilled');
      g.place(2, 4, 0);
      expect(g.tray.every((p) => p != null), isTrue, reason: 'refilled now');
      expect(g.tray[0]!.seqIndex, greaterThan(firstSeq));
    });

    test('reaching the goal wins and records progress', () async {
      final save = await SaveData.load();
      final preset = List<int>.filled(kCellCount, 0);
      for (var x = 0; x < 7; x++) {
        preset[x] = PresetCell.filled;
      }
      final level = Level(
        id: 1,
        chapter: 1,
        goal: GoalType.clearLines,
        target: 1,
        moveLimit: 0,
        preset: preset,
        shapePool: const <int>[0],
        seed: 3,
        starTargets: const <int>[5, 10, 20],
      );
      final g = GameController(level: level, save: save);
      g.place(0, 7, 0);
      expect(g.status, LevelStatus.won);
      expect(g.stars, greaterThanOrEqualTo(1));
      expect(save.currentLevel, 2);
      expect(save.starsFor(1), g.stars);
    });

    test('running out of moves loses', () async {
      final save = await SaveData.load();
      final g = GameController(
        level: testLevel(goal: GoalType.clearLines, target: 8, moveLimit: 2),
        save: save,
      );
      g.place(0, 0, 0);
      expect(g.status, LevelStatus.playing);
      expect(g.movesLeft, 1);
      g.place(1, 0, 4);
      expect(g.status, LevelStatus.lost);
      expect(g.lossReason, LossReason.outOfMoves);
    });

    test('survive wins exactly on the target move', () async {
      final save = await SaveData.load();
      final level = Level(
        id: 1,
        chapter: 10,
        goal: GoalType.survive,
        target: 3,
        moveLimit: 3,
        preset: List<int>.filled(kCellCount, 0),
        shapePool: const <int>[0],
        seed: 11,
        starTargets: const <int>[1, 2, 3],
      );
      final g = GameController(level: level, save: save);
      g.place(0, 0, 0);
      g.place(1, 2, 0);
      expect(g.status, LevelStatus.playing);
      g.place(2, 4, 0);
      expect(g.status, LevelStatus.won);
    });
  });

  group('boosters', () {
    test('Rewind restores board, score, streak, tray and counters', () async {
      final save = await SaveData.load();
      final preset = List<int>.filled(kCellCount, 0);
      for (var x = 0; x < 7; x++) {
        preset[x] = PresetCell.filled;
      }
      // Dots only: cell (7,0) is the last gap in row 0 and nothing wider fits.
      final level = Level(
        id: 1,
        chapter: 1,
        goal: GoalType.clearLines,
        target: 99,
        moveLimit: 0,
        preset: preset,
        shapePool: const <int>[0],
        seed: 4242,
        starTargets: const <int>[10, 40, 80],
      );
      final g = GameController(level: level, save: save);

      final trayBefore = List<Piece?>.of(g.tray);
      final boardBefore = g.board.toString();

      g.place(0, 7, 0); // clears the row
      expect(g.board.linesCleared, 1);
      expect(g.streak, 1);

      final undoBefore = save.boosterCount(BoosterId.undo);
      expect(g.undo(), isTrue);

      expect(save.boosterCount(BoosterId.undo), undoBefore - 1);
      expect(g.board.toString(), boardBefore);
      expect(g.score, 0);
      expect(g.streak, 0);
      expect(g.board.linesCleared, 0);
      expect(g.movesUsed, 0);
      expect(
        g.tray.map((p) => p?.seqIndex),
        trayBefore.map((p) => p?.seqIndex),
      );
    });

    test('Rewind is unavailable with no snapshot or no booster', () async {
      final save = await SaveData.load();
      final g = GameController(level: testLevel(), save: save);
      expect(g.canUndo, isFalse);
      g.place(0, 0, 0);
      expect(g.canUndo, isTrue);
      save.boosters[BoosterId.undo] = 0;
      expect(g.canUndo, isFalse);
      expect(g.undo(), isFalse);
    });

    test('the undo stack is capped at five', () async {
      final save = await SaveData.load();
      save.boosters[BoosterId.undo] = 99;
      final level = Level(
        id: 1,
        chapter: 1,
        goal: GoalType.reachScore,
        target: 9999,
        moveLimit: 0,
        preset: List<int>.filled(kCellCount, 0),
        shapePool: const <int>[0],
        seed: 5,
        starTargets: const <int>[1, 2, 3],
      );
      final g = GameController(level: level, save: save);
      for (var i = 0; i < 8; i++) {
        g.place(i % 3, i, 0);
      }
      var undos = 0;
      while (g.undo()) {
        undos++;
      }
      expect(undos, 5);
    });

    test('Ink blast removes a cell, cannot target blocked cells', () async {
      final save = await SaveData.load();
      final preset = List<int>.filled(kCellCount, 0);
      preset[0] = PresetCell.blocked;
      preset[1] = PresetCell.filled;
      final g = GameController(
        level: testLevel(target: 99, preset: preset),
        save: save,
      );
      expect(g.canBlast, isTrue);

      g.startBlast();
      expect(g.blastMode, isTrue);
      expect(g.blastAt(0), isFalse, reason: 'blocked cells are not targets');
      expect(g.blastAt(1), isTrue);
      expect(g.board.kinds[1], Cell.empty);
      expect(g.blastMode, isFalse);
      expect(save.boosterCount(BoosterId.hammer), 2);
    });

    test(
      'Reshuffle is disabled on a fresh tray and works after a move',
      () async {
        final save = await SaveData.load();
        final g = GameController(level: testLevel(target: 99), save: save);
        expect(g.canReshuffle, isFalse, reason: 'tray is fresh');

        g.place(0, 0, 0);
        expect(g.canReshuffle, isTrue);
        final before = g.tray.map((p) => p?.seqIndex).toList();
        expect(g.reshuffle(), isTrue);
        expect(g.tray.map((p) => p?.seqIndex).toList(), isNot(before));
        expect(g.tray.every((p) => p != null), isTrue);
        expect(g.canReshuffle, isFalse, reason: 'fresh again');
      },
    );

    test('reshuffled pieces come from the level shape pool', () async {
      final save = await SaveData.load();
      save.boosters[BoosterId.refresh] = 20;
      const pool = <int>[3, 9];
      final level = Level(
        id: 1,
        chapter: 1,
        goal: GoalType.reachScore,
        target: 9999,
        moveLimit: 0,
        preset: List<int>.filled(kCellCount, 0),
        shapePool: pool,
        seed: 21,
        starTargets: const <int>[1, 2, 3],
      );
      final g = GameController(level: level, save: save);
      for (var i = 0; i < 10; i++) {
        g.place(0, 0, i % 8);
        g.reshuffle();
        for (final p in g.tray) {
          expect(pool.contains(p!.shapeIndex), isTrue);
        }
      }
    });
  });

  group('save data', () {
    test('round trips through shared preferences', () async {
      final save = await SaveData.load();
      save.recordResult(1, 3, 250);
      save.updateSettings((s) => s.reduceMotion = true);
      await save.save();

      final reloaded = await SaveData.load();
      expect(reloaded.currentLevel, 2);
      expect(reloaded.starsFor(1), 3);
      expect(reloaded.totalScore, 250);
      expect(reloaded.levelsCompleted, 1);
      expect(reloaded.settings.reduceMotion, isTrue);
    });

    test('a corrupt blob falls back to a fresh save', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kSaveKey: 'not json at all',
      });
      final save = await SaveData.load();
      expect(save.currentLevel, 1);
      expect(save.boosterCount(BoosterId.undo), 3);
    });

    test('a three star clear awards a booster', () async {
      final save = await SaveData.load();
      final before = BoosterId.all
          .map(save.boosterCount)
          .fold<int>(0, (a, b) => a + b);
      final awarded = save.recordResult(3, 3, 500);
      expect(awarded, isNotNull);
      final after = BoosterId.all
          .map(save.boosterCount)
          .fold<int>(0, (a, b) => a + b);
      expect(after, before + 1);
    });

    test('unlocking is linear', () async {
      final save = await SaveData.load();
      expect(save.isUnlocked(1), isTrue);
      expect(save.isUnlocked(2), isFalse);
      save.recordResult(1, 1, 10);
      expect(save.isUnlocked(2), isTrue);
      expect(save.isUnlocked(3), isFalse);
    });
  });

  // Plain `test`, not `testWidgets`: asset I/O is real async and never
  // completes under the widget tester's fake clock.
  group('level loader', () {
    test('loads chapter 1 from the shipped asset', () async {
      final level = await LevelLoader.instance.load(1);
      expect(level.id, 1);
      expect(level.chapter, 1);
      expect(level.preset.length, kCellCount);
      expect(level.shapePool, isNotEmpty);
      expect(level.starTargets.length, 3);
    });

    test('caches the current level plus the next three', () async {
      await LevelLoader.instance.load(10);
      final sw = Stopwatch()..start();
      for (var i = 10; i <= 13; i++) {
        await LevelLoader.instance.load(i);
      }
      sw.stop();
      // Cached reads must be far inside the 16ms per level budget.
      expect(sw.elapsedMilliseconds, lessThan(16));
    });
  });

  group('shipped levels play through the real controller', () {
    // The strongest check in the suite: it proves the solver, the piece
    // sequence, the tray refill rule and the goal tracking all agree. If the
    // controller and the solver ever drift apart, a shipped level becomes
    // unwinnable and this fails.
    test('the solver solution wins levels 1 to 8 when replayed', () async {
      for (var id = 1; id <= 8; id++) {
        LevelLoader.instance.debugReset();
        final level = await LevelLoader.instance.load(id);
        final solution = Solver(level, nodeBudget: 200000).solve();
        expect(solution.solved, isTrue, reason: 'level $id is unsolvable');

        final save = await SaveData.load();
        final g = GameController(level: level, save: save);
        for (final m in solution.solution) {
          final ok = g.place(m.slot, m.bx, m.by);
          expect(
            ok,
            isTrue,
            reason: 'level $id rejected $m at move ${g.movesUsed + 1}',
          );
        }
        expect(g.status, LevelStatus.won, reason: 'level $id did not win');
      }
    });

    test('the greedy baseline loses level 1, so it needs thought', () async {
      LevelLoader.instance.debugReset();
      final level = await LevelLoader.instance.load(1);
      // Chapters 1 and 2 ship unlimited, so the par the generator validated
      // against is not in the file. parMin is the safe stand-in: greedy failing
      // within the real par implies it also fails within any smaller budget,
      // so this can never fail on a level the generator would have accepted.
      final par = level.moveLimit > 0
          ? level.moveLimit
          : paramsFor(level.chapter).parMin;
      expect(Solver(level, nodeBudget: 40000).greedySolvesWithin(par), isFalse);
    });
  });

  group('game screen', () {
    testWidgets('renders the board, tray and boosters', (tester) async {
      final save = await SaveData.load();
      // Warm the level cache on the real event loop: the screen's own load is
      // async and a fake-time pump will not wait for asset I/O.
      await tester.runAsync(() => LevelLoader.instance.load(1));
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(levelId: 1, save: save)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BoardView), findsOneWidget);
      expect(find.byType(TrayView), findsOneWidget);
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('Rewind'), findsOneWidget);
      expect(find.text('Ink blast'), findsOneWidget);
      expect(find.text('Reshuffle'), findsOneWidget);
    });

    testWidgets('dragging a tray piece onto the board places it', (
      tester,
    ) async {
      await pumpLevelOne(tester, size: const Size(420, 900));
      await dragFirstPieceOntoBoard(tester);

      // Read the score out of the header specifically. Matching "any Text
      // holding a number above zero" passes on the booster count badges, which
      // is how a stuck-drag bug survived this test once already.
      expect(scoreInHeader(tester), greaterThan(0));
    });
  });

  group('home screen', () {
    testWidgets('Play opens the current level with the map behind it', (
      tester,
    ) async {
      // The map underneath is the whole point of pushing two routes. Without
      // it, backing out of a level lands on the home screen while the level's
      // back arrow and the result sheet's "Map" button both say otherwise.
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final save = await SaveData.load();
      save.currentLevel = 4;
      await tester.runAsync(() => LevelLoader.instance.load(4));
      await tester.pumpWidget(MaterialApp(home: HomeScreen(save: save)));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Play'));
      // Fixed pumps rather than pumpAndSettle: the mascot's clock never stops,
      // so nothing on this screen ever settles. 400ms clears the route
      // transition, the last pump lets the level finish loading.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.text('Level 4'), findsOneWidget);

      // Leave the level: the map, not the home screen, is what is underneath.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // One more frame: the exit transition finishing and the route being torn
      // off the stack are two separate frames.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
    });

    testWidgets('a returning player is offered Continue, not Play', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final save = await SaveData.load();
      save.recordResult(1, 3, 120);
      await tester.pumpWidget(MaterialApp(home: HomeScreen(save: save)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Play'), findsNothing);
      expect(find.text('Level 2'), findsOneWidget);
    });
  });

  group('Ink blast', () {
    /// The blastable cells of level 1, in board order.
    Future<List<int>> targetsOnLevelOne() async {
      final level = await LevelLoader.instance.load(1);
      final start = BoardState.fromPreset(level.preset, level.seed);
      return <int>[
        for (var i = 0; i < kCellCount; i++)
          if (Cell.blastable(start.kinds[i])) i,
      ];
    }

    Future<void> tapCell(WidgetTester tester, int index) async {
      final board = tester.getRect(find.byType(BoardView));
      final cell = board.width / kBoardSize;
      await tester.tapAt(
        Offset(
          board.left + (index % kBoardSize + 0.5) * cell,
          board.top + (index ~/ kBoardSize + 0.5) * cell,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }

    testWidgets('the block survives the swing and breaks on impact', (
      tester,
    ) async {
      // The point of the whole change: the player has to see the hammer hit
      // the thing they aimed at. Removing the block on the tap left the swing
      // landing on an already empty square.
      final save = await pumpLevelOne(tester);
      final before = save.boosterCount(BoosterId.hammer);

      await tester.tap(find.text('Ink blast'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(BlastHammer), findsNothing, reason: 'nothing aimed at');

      await tapCell(tester, (await targetsOnLevelOne()).first);

      // Mid swing: the hammer is in the air and nothing has been spent.
      expect(find.byType(BlastHammer), findsOneWidget);
      expect(
        save.boosterCount(BoosterId.hammer),
        before,
        reason: 'the booster was spent before the hammer landed',
      );

      // Past the impact frame.
      await tester.pump(BlastHammer.duration * (BlastHammer.impactAt + 0.05));
      expect(
        save.boosterCount(BoosterId.hammer),
        before - 1,
        reason: 'the block did not break on impact',
      );

      // And the hammer takes itself down afterwards.
      await tester.pump(BlastHammer.duration);
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(BlastHammer), findsNothing);
    });

    testWidgets('a second tap during the swing cannot spend another booster', (
      tester,
    ) async {
      final save = await pumpLevelOne(tester);
      final before = save.boosterCount(BoosterId.hammer);

      await tester.tap(find.text('Ink blast'));
      await tester.pump(const Duration(milliseconds: 100));

      final targets = await targetsOnLevelOne();
      expect(targets.length, greaterThan(1), reason: 'need two filled cells');
      await tapCell(tester, targets[0]);
      await tapCell(tester, targets[1]);
      expect(find.byType(BlastHammer), findsOneWidget);

      await tester.pump(BlastHammer.duration);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        save.boosterCount(BoosterId.hammer),
        before - 1,
        reason: 'the second tap started a second swing',
      );
    });

    testWidgets('an empty square does not start a swing', (tester) async {
      // The board reports a tap on every square, not only on the ones that can
      // be hit. Swinging at an empty one played the whole animation and broke
      // nothing, which looked exactly like the hammer failing to work.
      final save = await pumpLevelOne(tester);
      final before = save.boosterCount(BoosterId.hammer);

      await tester.tap(find.text('Ink blast'));
      await tester.pump(const Duration(milliseconds: 100));

      final level = await LevelLoader.instance.load(1);
      final start = BoardState.fromPreset(level.preset, level.seed);
      final empty = List<int>.generate(kCellCount, (i) => i)
          .firstWhere((i) => start.kinds[i] == Cell.empty);
      await tapCell(tester, empty);

      expect(find.byType(BlastHammer), findsNothing);
      expect(save.boosterCount(BoosterId.hammer), before);

      // Still armed, so the next tap on a real block works.
      await tapCell(tester, (await targetsOnLevelOne()).first);
      expect(find.byType(BlastHammer), findsOneWidget);
    });

    testWidgets('reduce motion blasts straight away, with no swing', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final save = await SaveData.load();
      save.updateSettings((s) => s.reduceMotion = true);
      final before = save.boosterCount(BoosterId.hammer);

      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.runAsync(() => LevelLoader.instance.load(1));
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(levelId: 1, save: save)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(206, 60)); // dismiss the tutorial
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Ink blast'));
      await tester.pump(const Duration(milliseconds: 100));
      await tapCell(tester, (await targetsOnLevelOne()).first);

      expect(find.byType(BlastHammer), findsNothing);
      expect(save.boosterCount(BoosterId.hammer), before - 1);
    });
  });

  group('pause', () {
    testWidgets('the pause button opens the menu and resume closes it', (
      tester,
    ) async {
      await pumpLevelOne(tester);

      expect(find.text('Paused'), findsNothing);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Restart level'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Quit to map'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Paused'), findsNothing);
    });

    testWidgets('the veil swallows a drag that would otherwise place', (
      tester,
    ) async {
      // The whole point of the overlay. A pause that leaves the board live is
      // worse than no pause: the player puts the phone in a pocket and comes
      // back to a piece dropped somewhere they never chose.
      await pumpLevelOne(tester);

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      await dragFirstPieceOntoBoard(tester);
      expect(
        scoreInHeader(tester),
        0,
        reason: 'a piece was placed while the game was paused',
      );

      // And the same drag lands once the veil is gone, so the assertion above
      // is about the pause and not about the drag being wrong.
      await tester.tap(find.text('Resume'));
      await tester.pump(const Duration(milliseconds: 100));
      await dragFirstPieceOntoBoard(tester);
      expect(scoreInHeader(tester), greaterThan(0));
    });

    testWidgets('restarting from the pause menu clears the board', (
      tester,
    ) async {
      await pumpLevelOne(tester);
      await dragFirstPieceOntoBoard(tester);
      expect(scoreInHeader(tester), greaterThan(0));

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Restart level'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Paused'), findsNothing);
      expect(scoreInHeader(tester), 0);
    });

    testWidgets('the system back gesture resumes instead of leaving', (
      tester,
    ) async {
      await pumpLevelOne(tester);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Paused'), findsOneWidget);

      // What the platform sends on an Android back press or an edge swipe.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Paused'), findsNothing, reason: 'back should resume');
      expect(
        find.byType(GameScreen),
        findsOneWidget,
        reason: 'back should not have left the level',
      );
    });
  });
}
