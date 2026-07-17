import 'package:blocktopus/game/board_state.dart';
import 'package:blocktopus/models/level.dart';
import 'package:blocktopus/models/piece.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a board from an 8 line ASCII sketch. `.` empty, digits are cell
/// kinds. Keeps the tests readable.
BoardState boardFrom(List<String> rows) {
  final preset = List<int>.filled(kCellCount, 0);
  for (var y = 0; y < rows.length; y++) {
    for (var x = 0; x < rows[y].length; x++) {
      final ch = rows[y][x];
      preset[y * kBoardSize + x] = ch == '.' ? 0 : int.parse(ch);
    }
  }
  return BoardState.fromPreset(preset, 1);
}

Shape shape(String name) => kShapes.firstWhere((s) => s.name == name);

void main() {
  group('placement validity', () {
    test('a piece fits on an empty board', () {
      final b = BoardState.empty();
      expect(b.canPlace(shape('square2'), 0, 0), isTrue);
      expect(b.canPlace(shape('square2'), 6, 6), isTrue);
    });

    test('a piece may not hang off the edge', () {
      final b = BoardState.empty();
      expect(b.canPlace(shape('square2'), 7, 0), isFalse);
      expect(b.canPlace(shape('penta-h'), 4, 0), isFalse);
      expect(b.canPlace(shape('penta-h'), 3, 0), isTrue);
      expect(b.canPlace(shape('quad-v'), 0, 5), isFalse);
    });

    test('a piece may not overlap any occupied cell', () {
      final b = boardFrom([
        '..2.....',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      expect(b.canPlace(shape('square2'), 1, 0), isFalse);
      expect(b.canPlace(shape('square2'), 3, 0), isTrue);
    });

    test('blocked cells reject placement just like filled cells', () {
      final b = boardFrom([
        '1.......',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      expect(b.canPlace(shape('dot'), 0, 0), isFalse);
      expect(b.canPlace(shape('dot'), 1, 0), isTrue);
    });

    test('negative coordinates are rejected', () {
      final b = BoardState.empty();
      expect(b.canPlace(shape('dot'), -1, 0), isFalse);
      expect(b.canPlace(shape('dot'), 0, -1), isFalse);
    });

    test('place returns rejected and leaves the board untouched', () {
      final b = boardFrom([
        '2.......',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      final before = b.toString();
      final r = b.place(shape('dot'), 0, 0, 0);
      expect(r.ok, isFalse);
      expect(b.toString(), before);
      expect(b.score, 0);
      expect(b.movesUsed, 0);
    });
  });

  group('line clearing', () {
    test('a completed row clears', () {
      final b = boardFrom([
        '2222222.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      final r = b.place(shape('dot'), 7, 0, 0);
      expect(r.linesCleared, 1);
      expect(r.rowsCleared, 1);
      expect(r.colsCleared, 0);
      for (var x = 0; x < kBoardSize; x++) {
        expect(b.kindAt(x, 0), Cell.empty);
      }
    });

    test('a completed column clears', () {
      final b = boardFrom([
        '2.......',
        '2.......',
        '2.......',
        '2.......',
        '2.......',
        '2.......',
        '2.......',
        '........',
      ]);
      final r = b.place(shape('dot'), 0, 7, 0);
      expect(r.linesCleared, 1);
      expect(r.colsCleared, 1);
      for (var y = 0; y < kBoardSize; y++) {
        expect(b.kindAt(0, y), Cell.empty);
      }
    });

    test('a row and a column clear simultaneously from one placement', () {
      // Row 0 needs (7,0). Column 7 needs (7,0) too, so one dot does both.
      final b = boardFrom([
        '2222222.',
        '.......2',
        '.......2',
        '.......2',
        '.......2',
        '.......2',
        '.......2',
        '.......2',
      ]);
      final r = b.place(shape('dot'), 7, 0, 0);
      expect(r.rowsCleared, 1);
      expect(r.colsCleared, 1);
      expect(r.linesCleared, 2);
      // Both lines gone.
      for (var x = 0; x < kBoardSize; x++) {
        expect(b.kindAt(x, 0), Cell.empty);
      }
      for (var y = 0; y < kBoardSize; y++) {
        expect(b.kindAt(7, y), Cell.empty);
      }
      // The shared corner is counted once, not twice.
      expect(r.clearedCells.length, kBoardSize * 2 - 1);
    });

    test('three rows clear at once', () {
      final b = boardFrom([
        '.2222222',
        '.2222222',
        '.2222222',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      final r = b.place(shape('tri-v'), 0, 0, 0);
      expect(r.linesCleared, 3);
      expect(b.filledCount, 0);
    });

    test('a blocked cell counts as filled but survives the clear', () {
      final b = boardFrom([
        '1222222.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      final r = b.place(shape('dot'), 7, 0, 0);
      expect(r.linesCleared, 1);
      expect(b.kindAt(0, 0), Cell.blocked);
      expect(b.kindAt(1, 0), Cell.empty);
    });
  });

  group('stars', () {
    test('a star is collected when a line clears through it', () {
      final b = boardFrom([
        '6222222.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      expect(b.kindAt(0, 0), Cell.star);
      final r = b.place(shape('dot'), 7, 0, 0);
      expect(r.linesCleared, 1);
      expect(r.starsCollected, <int>[0]);
      expect(b.starsTaken, 1);
      expect(b.kindAt(0, 0), Cell.empty, reason: 'a star clears in one hit');
    });

    test('a star blocks placement and completes a line like any block', () {
      // The whole design: it changes what you aim at, not how the game works.
      final b = boardFrom([
        '6.......',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      expect(b.canPlace(shape('dot'), 0, 0), isFalse);
      expect(b.place(shape('penta-h'), 1, 0, 0).linesCleared, 0);
      expect(b.place(shape('duo-h'), 6, 0, 0).linesCleared, 1);
    });

    test('a star sitting outside the cleared line survives', () {
      final b = boardFrom([
        '.222222.',
        '6.......',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      b.place(shape('dot'), 0, 0, 0);
      final r = b.place(shape('dot'), 7, 0, 0);
      expect(r.linesCleared, 1);
      expect(r.starsCollected, isEmpty);
      expect(b.kindAt(0, 1), Cell.star);
      expect(b.starsTaken, 0);
    });

    test('one star in a crossing row and column counts once', () {
      // The same rule the rest of the board follows: a cell caught by both a
      // row and a column takes one hit, not two. Counting the star twice would
      // finish a collection goal early.
      // The star sits at the crossing of row 0 and column 5. Column 5 is
      // already complete, so the one dot that finishes row 0 clears both.
      final b = boardFrom([
        '2222262.',
        '.....2..',
        '.....2..',
        '.....2..',
        '.....2..',
        '.....2..',
        '.....2..',
        '.....2..',
      ]);
      final r = b.place(shape('dot'), 7, 0, 0);
      expect(r.rowsCleared, 1);
      expect(r.colsCleared, 1);
      expect(r.starsCollected.length, 1);
      expect(b.starsTaken, 1);
    });

    test('Ink blast on a star collects it', () {
      // Otherwise a booster could strand a collection level: the star would be
      // gone from the board without ever counting.
      final b = boardFrom([
        '6.......',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      expect(b.blast(0), isTrue);
      expect(b.starsTaken, 1);
      expect(b.kindAt(0, 0), Cell.empty);
    });

    test('undo restores the star and the count', () {
      final b = boardFrom([
        '6222222.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      final before = b.clone();
      b.place(shape('dot'), 7, 0, 0);
      expect(b.starsTaken, 1);
      expect(before.starsTaken, 0, reason: 'the snapshot must not share state');
      expect(before.kindAt(0, 0), Cell.star);
    });
  });

  group('special cells', () {
    test('jelly clears when a line passes through it', () {
      final b = boardFrom([
        '3222222.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      final r = b.place(shape('dot'), 7, 0, 0);
      expect(r.jellyCleared, 1);
      expect(b.kindAt(0, 0), Cell.empty);
    });

    test('double jelly softens to jelly, then clears', () {
      final b = boardFrom([
        '4222222.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      var r = b.place(shape('dot'), 7, 0, 0);
      expect(r.jellyCleared, 0, reason: 'first line only softens it');
      expect(b.kindAt(0, 0), Cell.jelly);

      // Rebuild the row and clear it a second time.
      b.place(shape('penta-h'), 1, 0, 0);
      r = b.place(shape('duo-h'), 6, 0, 0);
      expect(r.linesCleared, 1);
      expect(r.jellyCleared, 1);
      expect(b.kindAt(0, 0), Cell.empty);
      expect(b.jellyCleared, 1);
    });

    test('stone softens to a normal block, then clears', () {
      final b = boardFrom([
        '5222222.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      b.place(shape('dot'), 7, 0, 0);
      expect(b.kindAt(0, 0), Cell.filled);
      // Rebuild the row: cells 1..7 are empty now.
      b.place(shape('penta-h'), 1, 0, 0);
      b.place(shape('duo-h'), 6, 0, 0);
      expect(b.kindAt(0, 0), Cell.empty); // cleared on the second line
    });

    test('breakBlocks counts only preset blocks', () {
      final b = boardFrom([
        '2222....',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      final r = b.place(shape('quad-h'), 4, 0, 0);
      expect(r.linesCleared, 1);
      expect(r.blocksBroken, 4); // the four preset ones only
      expect(b.blocksBroken, 4);
    });
  });

  group('scoring', () {
    test('a placement with no clear scores one per cell', () {
      final b = BoardState.empty();
      final r = b.place(shape('square2'), 0, 0, 0);
      expect(r.scoreGained, 4);
      expect(b.score, 4);
      expect(b.streak, 0);
    });

    test('one line scores cells + 10', () {
      final b = boardFrom([
        '2222222.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      final r = b.place(shape('dot'), 7, 0, 0);
      // 1 cell + 1*10*1, streak becomes 1 so no streak bonus.
      expect(r.scoreGained, 11);
    });

    test('two lines score cells + 40', () {
      final b = boardFrom([
        '2222222.',
        '.......2',
        '.......2',
        '.......2',
        '.......2',
        '.......2',
        '.......2',
        '.......2',
      ]);
      final r = b.place(shape('dot'), 7, 0, 0);
      expect(r.scoreGained, 1 + 40);
    });

    test('three lines score cells + 90', () {
      final b = boardFrom([
        '.2222222',
        '.2222222',
        '.2222222',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      final r = b.place(shape('tri-v'), 0, 0, 0);
      expect(r.scoreGained, 3 + 90);
    });

    test('streak increments on clears and adds a bonus past one', () {
      final b = boardFrom([
        '2222222.',
        '2222222.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      final first = b.place(shape('dot'), 7, 0, 0);
      expect(first.streakAfter, 1);
      expect(first.scoreGained, 11); // no bonus at streak 1

      final second = b.place(shape('dot'), 7, 1, 0);
      expect(second.streakAfter, 2);
      // 1 cell + 10 + streak 2 * 5
      expect(second.scoreGained, 1 + 10 + 10);
    });

    test('streak resets on a placement that clears nothing', () {
      final b = boardFrom([
        '2222222.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      b.place(shape('dot'), 7, 0, 0);
      expect(b.streak, 1);
      b.place(shape('dot'), 0, 5, 0);
      expect(b.streak, 0);
    });

    test('clearStreak mirrors streak for the audio pitch ladder', () {
      final b = boardFrom([
        '2222222.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      b.place(shape('dot'), 7, 0, 0);
      expect(b.clearStreak, 1);
    });
  });

  group('game over', () {
    test('an empty board is never game over', () {
      final b = BoardState.empty();
      final tray = <Piece?>[
        const Piece(shapeIndex: 10, colorIndex: 0, seqIndex: 0),
      ];
      expect(b.isGameOver(tray), isFalse);
    });

    test('game over when nothing in the tray fits', () {
      // Checkerboard: no shape larger than a dot fits, and no empty cell is
      // adjacent to another empty cell.
      final rows = <String>[];
      for (var y = 0; y < 8; y++) {
        final sb = StringBuffer();
        for (var x = 0; x < 8; x++) {
          sb.write((x + y).isEven ? '2' : '.');
        }
        rows.add(sb.toString());
      }
      final b = boardFrom(rows);
      final duo = kShapes.indexWhere((s) => s.name == 'duo-h');
      final tray = <Piece?>[Piece(shapeIndex: duo, colorIndex: 0, seqIndex: 0)];
      expect(b.isGameOver(tray), isTrue);

      final dot = kShapes.indexWhere((s) => s.name == 'dot');
      expect(
        b.isGameOver(<Piece?>[
          Piece(shapeIndex: dot, colorIndex: 0, seqIndex: 0),
        ]),
        isFalse,
      );
    });

    test('used tray slots are ignored', () {
      final b = BoardState.empty();
      expect(b.isGameOver(<Piece?>[null, null, null]), isTrue);
    });
  });

  group('undo snapshots', () {
    test('clone is a deep, complete copy', () {
      final b = boardFrom([
        '2222222.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      b.place(shape('dot'), 7, 0, 0);
      final snap = b.clone();

      b.place(shape('square3'), 0, 0, 1);
      expect(b.score, isNot(snap.score));
      expect(b.toString(), isNot(snap.toString()));

      expect(snap.score, 11);
      expect(snap.streak, 1);
      expect(snap.linesCleared, 1);
      expect(snap.movesUsed, 1);
      expect(snap.filledCount, 0);
    });
  });

  group('ink blast', () {
    test('removes a filled cell but not a blocked one', () {
      final b = boardFrom([
        '12......',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      expect(b.blast(0), isFalse);
      expect(b.blast(1), isTrue);
      expect(b.kindAt(1, 0), Cell.empty);
    });

    test('does not score and does not touch the streak', () {
      final b = boardFrom([
        '2222222.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      b.place(shape('dot'), 7, 1, 0); // no clear, streak 0
      final score = b.score;
      b.blast(0);
      expect(b.score, score);
      expect(b.streak, 0);
      expect(b.movesUsed, 1);
    });
  });

  group('goals', () {
    Level lvl(GoalType goal, int target) => Level(
      id: 1,
      chapter: 1,
      goal: goal,
      target: target,
      moveLimit: 0,
      preset: List<int>.filled(kCellCount, 0),
      shapePool: const <int>[0],
      seed: 1,
      starTargets: const <int>[10, 20, 30],
    );

    test('clearLines', () {
      final b = boardFrom([
        '2222222.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      expect(b.goalMet(lvl(GoalType.clearLines, 1)), isFalse);
      b.place(shape('dot'), 7, 0, 0);
      expect(b.goalMet(lvl(GoalType.clearLines, 1)), isTrue);
    });

    test('reachScore', () {
      final b = BoardState.empty();
      b.place(shape('square3'), 0, 0, 0);
      expect(b.goalMet(lvl(GoalType.reachScore, 9)), isTrue);
      expect(b.goalMet(lvl(GoalType.reachScore, 10)), isFalse);
    });

    test('survive counts moves', () {
      final b = BoardState.empty();
      b.place(shape('dot'), 0, 0, 0);
      b.place(shape('dot'), 2, 0, 0);
      expect(b.goalMet(lvl(GoalType.survive, 2)), isTrue);
    });
  });

  group('largest empty rectangle', () {
    test('an empty board is 64', () {
      expect(BoardState.empty().largestEmptyRect(), 64);
    });

    test('a full board is 0', () {
      final rows = List<String>.filled(8, '22222222');
      expect(boardFrom(rows).largestEmptyRect(), 0);
    });

    test('finds a 4x8 half', () {
      final rows = <String>[
        ...List<String>.filled(4, '22222222'),
        ...List<String>.filled(4, '........'),
      ];
      expect(boardFrom(rows).largestEmptyRect(), 32);
    });
  });

  group('shape library', () {
    test('every shape id matches its index', () {
      for (var i = 0; i < kShapes.length; i++) {
        expect(kShapes[i].id, i, reason: 'shape ${kShapes[i].name}');
      }
    });

    test('no shape exceeds the board and none is empty', () {
      for (final s in kShapes) {
        expect(s.w, lessThanOrEqualTo(kBoardSize));
        expect(s.h, lessThanOrEqualTo(kBoardSize));
        expect(s.cells, isNotEmpty);
        for (final c in s.cells) {
          expect(c, lessThan(s.w * s.h));
        }
      }
    });

    test('every shape touches all four edges of its bounding box', () {
      for (final s in kShapes) {
        final xs = s.cells.map((c) => c % s.w).toSet();
        final ys = s.cells.map((c) => c ~/ s.w).toSet();
        expect(xs.contains(0), isTrue, reason: '${s.name} left');
        expect(xs.contains(s.w - 1), isTrue, reason: '${s.name} right');
        expect(ys.contains(0), isTrue, reason: '${s.name} top');
        expect(ys.contains(s.h - 1), isTrue, reason: '${s.name} bottom');
      }
    });
  });

  group('piece sequence', () {
    test('is deterministic and index addressable', () {
      const seq = PieceSequence(12345, <int>[0, 1, 9, 12]);
      final a = List.generate(20, (i) => seq.at(i).shapeIndex);
      final b = List.generate(20, (i) => seq.at(i).shapeIndex);
      expect(a, b);
      expect(seq.at(7).shapeIndex, a[7]);
    });

    test('only ever produces shapes from the pool', () {
      const pool = <int>[3, 9, 12];
      const seq = PieceSequence(99, pool);
      for (var i = 0; i < 500; i++) {
        expect(pool.contains(seq.at(i).shapeIndex), isTrue);
      }
    });

    test('colour indices stay inside the palette', () {
      const seq = PieceSequence(7, <int>[0]);
      for (var i = 0; i < 500; i++) {
        final c = seq.at(i).colorIndex;
        expect(c, greaterThanOrEqualTo(0));
        expect(c, lessThan(kPaletteSize));
      }
    });

    test('different seeds give different sequences', () {
      final a = List.generate(
        30,
        (i) => const PieceSequence(1, <int>[0, 1, 2, 3, 4, 5]).at(i).shapeIndex,
      );
      final b = List.generate(
        30,
        (i) => const PieceSequence(2, <int>[0, 1, 2, 3, 4, 5]).at(i).shapeIndex,
      );
      expect(a, isNot(b));
    });
  });

  group('level json', () {
    test('round trips', () {
      final l = Level(
        id: 42,
        chapter: 1,
        goal: GoalType.clearJelly,
        target: 6,
        moveLimit: 18,
        preset: List<int>.generate(kCellCount, (i) => i % 6),
        shapePool: const <int>[0, 3, 9],
        seed: 987654,
        starTargets: const <int>[50, 120, 200],
        difficulty: 0.6231,
      );
      final r = Level.fromJson(l.toJson());
      expect(r.id, l.id);
      expect(r.goal, l.goal);
      expect(r.target, l.target);
      expect(r.moveLimit, l.moveLimit);
      expect(r.preset, l.preset);
      expect(r.shapePool, l.shapePool);
      expect(r.seed, l.seed);
      expect(r.starTargets, l.starTargets);
      expect(r.difficulty, closeTo(l.difficulty, 0.0001));
    });

    test('chapter asset paths match the shipped file names', () {
      expect(chapterInfo(1).assetPath, 'assets/levels/levels_001_100.json');
      expect(chapterInfo(15).assetPath, 'assets/levels/levels_1401_1500.json');
    });

    test('chapterOf maps boundaries correctly', () {
      expect(chapterOf(1), 1);
      expect(chapterOf(100), 1);
      expect(chapterOf(101), 2);
      expect(chapterOf(1500), 15);
    });
  });
}
