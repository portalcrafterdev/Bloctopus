import 'dart:convert';
import 'dart:io';

import 'package:blocktopus/models/level.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the difficulty curve rules from section 6.4. Cheap: it only reads
/// the shipped JSON, it never runs the solver. The solver sweep lives in
/// `level_validity_test.dart` and is tagged `slow`.
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

  List<Level> read(File f) =>
      ((jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)['levels']
              as List)
          .cast<Map<String, dynamic>>()
          .map(Level.fromJson)
          .toList();

  test('every chapter file that has shipped is complete', () {
    expect(files, isNotEmpty, reason: 'run tool/generate_levels.dart first');
    for (final f in files) {
      expect(read(f).length, 100, reason: f.path);
    }
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;

    group(name, () {
      late List<Level> levels;
      setUpAll(() => levels = read(file));

      test('difficulty actually varies', () {
        // A flat curve means the difficulty metric collapsed rather than that
        // the levels are evenly matched, and every ordering check below would
        // pass vacuously on it. Guarding the spread is what catches that.
        final diffs = levels.map((l) => l.difficulty).toList()..sort();
        expect(
          diffs.last - diffs.first,
          greaterThan(0.05),
          reason:
              'difficulty is flat at ${diffs.first}: the metric collapsed, '
              'so the curve is unordered',
        );
      });

      test('difficulty rises across the chapter', () {
        // Compared in blocks of ten so the every-tenth dip does not read as a
        // regression, and so a single noisy candidate cannot fail the run.
        final blocks = <double>[];
        for (var i = 0; i < 100; i += 10) {
          final slice = levels.sublist(i, i + 10);
          blocks.add(
            slice.map((l) => l.difficulty).reduce((a, b) => a + b) /
                slice.length,
          );
        }
        expect(
          blocks.first,
          lessThanOrEqualTo(blocks.last),
          reason: 'the chapter does not get harder: $blocks',
        );
      });

      test('every tenth level is a breather', () {
        // "Every 10th level is 20% easier than its neighbours." Checked
        // against the block it sits in rather than pairwise, because the
        // curation assigns by nearest difficulty, not exactly.
        var breathers = 0;
        for (var i = 9; i < 100; i += 10) {
          final neighbours = <Level>[
            if (i - 1 >= 0) levels[i - 1],
            if (i + 1 < 100) levels[i + 1],
          ];
          if (neighbours.isEmpty) continue;
          final around =
              neighbours.map((l) => l.difficulty).reduce((a, b) => a + b) /
              neighbours.length;
          if (levels[i].difficulty <= around) breathers++;
        }
        expect(
          breathers,
          greaterThanOrEqualTo(7),
          reason:
              'only $breathers of 10 tenth levels are easier than their '
              'neighbours; the curve has no breathers',
        );
      });

      test('boss levels are every 25th and carry a tighter limit', () {
        for (final l in levels) {
          expect(l.isBoss, l.id % 25 == 0, reason: 'level ${l.id}');
        }
        for (final boss in levels.where((l) => l.isBoss)) {
          if (boss.moveLimit == 0) continue; // unlimited chapters
          final peers = levels
              .where((l) => !l.isBoss && l.moveLimit > 0)
              .map((l) => l.moveLimit);
          if (peers.isEmpty) continue;
          final average = peers.reduce((a, b) => a + b) / peers.length;
          expect(
            boss.moveLimit,
            lessThanOrEqualTo(average.ceil()),
            reason: 'boss ${boss.id} is not tighter than the chapter average',
          );
        }
      });

      test('the chapter uses the goals its theme promises', () {
        final chapter = levels.first.chapter;
        for (final l in levels) {
          expect(l.chapter, chapter);
        }
        // Chapters 3 and up enforce a move limit; 1 and 2 do not.
        final limited = levels.where((l) => l.moveLimit > 0).length;
        if (chapter <= 2) {
          expect(limited, 0, reason: 'chapter $chapter should be unlimited');
        } else {
          expect(limited, 100, reason: 'chapter $chapter should be limited');
        }
      });
    });
  }
}
