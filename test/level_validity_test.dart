@Tags(<String>['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:blocktopus/game/board_state.dart';
import 'package:blocktopus/game/solver.dart';
import 'package:blocktopus/models/level.dart';
import 'package:blocktopus/models/piece.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_levels.dart' show paramsFor;

/// Walks every shipped level file and re-proves each level.
///
/// This is the gate from section 14: nothing ships that the solver cannot
/// solve inside its move limit. It is slow, so it is tagged `slow` and run in
/// CI only:
///
///   flutter test --tags slow test/level_validity_test.dart
void main() {
  final dir = Directory('assets/levels');
  final files = dir.existsSync()
      ? (dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  test('at least one chapter has shipped', () {
    expect(files, isNotEmpty, reason: 'run tool/generate_levels.dart first');
  });

  for (final file in files) {
    group(file.uri.pathSegments.last, () {
      late List<Level> levels;

      setUpAll(() {
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        levels = (json['levels'] as List)
            .cast<Map<String, dynamic>>()
            .map(Level.fromJson)
            .toList();
      });

      test('holds 100 levels with contiguous ids', () {
        expect(levels.length, 100);
        for (var i = 1; i < levels.length; i++) {
          expect(levels[i].id, levels[i - 1].id + 1);
        }
      });

      test('every level is well formed', () {
        for (final l in levels) {
          expect(l.preset.length, kCellCount, reason: 'level ${l.id}');
          expect(
            l.preset.every((c) => c >= 0 && c <= 5),
            isTrue,
            reason: 'level ${l.id} has an unknown cell kind',
          );
          expect(l.shapePool, isNotEmpty, reason: 'level ${l.id}');
          expect(
            l.shapePool.every((s) => s >= 0 && s < kShapes.length),
            isTrue,
            reason: 'level ${l.id} points at a shape that does not exist',
          );
          expect(l.starTargets.length, 3, reason: 'level ${l.id}');
          expect(l.target, greaterThan(0), reason: 'level ${l.id}');

          final board = BoardState.fromPreset(l.preset, l.seed);
          expect(
            board.filledCount,
            greaterThan(0),
            reason: 'level ${l.id} starts empty',
          );
          expect(
            board.density,
            lessThanOrEqualTo(0.45),
            reason: 'level ${l.id} starts more than 45% full',
          );
        }
      });

      test('star targets rise', () {
        for (final l in levels) {
          expect(
            l.starTargets[0],
            lessThanOrEqualTo(l.starTargets[1]),
            reason: 'level ${l.id}',
          );
          expect(
            l.starTargets[1],
            lessThan(l.starTargets[2]),
            reason: 'level ${l.id}',
          );
        }
      });

      test('every level is solvable inside its move limit', () {
        final failures = <int>[];
        for (final l in levels) {
          final solver = Solver(l, nodeBudget: kGeneratorNodeBudget);
          final r = solver.solve();
          if (!r.solved) failures.add(l.id);
        }
        expect(failures, isEmpty, reason: 'unsolvable levels: $failures');
      });

      test('no level falls to the greedy baseline', () {
        final trivial = <int>[];
        for (final l in levels) {
          // Chapters 1 and 2 ship unlimited, so the par the generator actually
          // validated against - a draw somewhere in [parMin, parMax] - is not
          // stored in the file. parMin is the safe stand-in: greedy failing
          // within the real par implies it fails within any smaller budget, so
          // this can never fail on a level the generator would have accepted.
          // A hardcoded number cannot make that claim, and a too-generous one
          // fails levels that are perfectly good.
          final par = l.moveLimit > 0
              ? l.moveLimit
              : paramsFor(l.chapter).parMin;
          if (Solver(l, nodeBudget: 40000).greedySolvesWithin(par)) {
            trivial.add(l.id);
          }
        }
        expect(trivial, isEmpty, reason: 'greedy beat: $trivial');
      });
    });
  }
}
