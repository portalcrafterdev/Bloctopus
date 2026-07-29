import 'dart:math';

import 'package:blocktopus/app/theme.dart';
import 'package:blocktopus/widgets/combo_text.dart';
import 'package:blocktopus/widgets/particle_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Section 10.1 caps the field at 400 live particles and asks for one painter
/// for all of them. Section 15 wants a 60fps check with 400 live particles on
/// a low end device; that part is manual, but the cap, the decay and the
/// single-painter shape are all checkable here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('particle field', () {
    test('never exceeds the cap, dropping the oldest', () {
      final c = ParticleController();
      // A full board clear is 64 cells at up to 9 particles each: far more
      // than the cap, which is exactly the case the cap exists for.
      for (var i = 0; i < 64; i++) {
        c.burstCell(const Offset(100, 100), palette[i % palette.length], 40);
      }
      expect(c.particles.length, lessThanOrEqualTo(kMaxParticles));
      expect(c.particles.length, kMaxParticles);
    });

    test('reduce motion halves the emission', () {
      final full = ParticleController();
      final reduced = ParticleController()..reduceMotion = true;
      full.burstCell(Offset.zero, palette.first, 40);
      reduced.burstCell(Offset.zero, palette.first, 40);
      expect(reduced.particles.length, lessThan(full.particles.length));
    });

    test('particles expire, so the field drains on its own', () {
      final c = ParticleController()..burstCell(Offset.zero, palette.first, 40);
      expect(c.isEmpty, isFalse);
      // Longest life is 34 frames; a little past that must be empty.
      for (var i = 0; i < 80; i++) {
        c.tick();
      }
      expect(c.isEmpty, isTrue);
    });

    test('a placement puff is subtle, not a burst', () {
      final c = ParticleController()..puff(Offset.zero, palette.first);
      expect(c.particles.length, 3);
    });

    group('a hammered block comes apart', () {
      // No golden for this: the shards fly on random velocities, so a golden
      // would fail against its own output. These are the properties that make
      // it read as breakage rather than as a puff of dust.
      const cell = 46.0;

      test('into four quarters, each a real piece of the block', () {
        final c = ParticleController()
          ..shatterCell(const Offset(100, 100), palette.first, cell);
        final shards = c.particles.where((p) => p.spin != 0).toList();

        expect(shards.length, 4, reason: 'a block has four quarters');
        for (final s in shards) {
          // Big enough that four of them look like the block that was there.
          expect(s.size, greaterThan(cell * 0.4));
          expect(s.color, palette.first);
          // Thrown upward: the hammer came down on them.
          expect(s.vy, lessThan(0));
        }
        // The quarters start apart, not stacked on one point.
        expect(shards.map((s) => s.x).toSet().length, greaterThan(1));
        expect(shards.map((s) => s.y).toSet().length, greaterThan(1));
      });

      test('the shards outlive the chips, so the break is the last thing seen', () {
        final c = ParticleController()
          ..shatterCell(const Offset(100, 100), palette.first, cell);
        final shards = c.particles.where((p) => p.spin != 0);
        final chips = c.particles.where((p) => p.spin == 0);
        expect(chips, isNotEmpty);
        expect(
          shards.map((s) => s.maxLife).reduce(min),
          greaterThan(chips.map((p) => p.maxLife).reduce(max)),
        );
      });

      test('every shard clears the square it came from', () {
        // The complaint this exists for: the first cut threw the quarters so
        // gently, and held them so opaque, that four pieces of the block sat
        // on its old square looking like it had never gone.
        const centre = Offset(100, 100);
        final c = ParticleController()
          ..shatterCell(centre, palette.first, cell);
        final shards = c.particles.where((p) => p.spin != 0).toList();

        // Half of the shortest life: it has to be well clear early, not at the
        // last frame before it vanishes.
        final frames = shards.map((s) => s.maxLife).reduce(min) ~/ 2;
        for (var i = 0; i < frames; i++) {
          c.tick();
        }

        for (final s in shards) {
          final travelled = (Offset(s.x, s.y) + Offset(s.size, s.size) / 2 -
                  centre)
              .distance;
          expect(
            travelled,
            greaterThan(cell),
            reason: 'a shard is still sitting on the cell it broke off',
          );
        }
      });

      test('the shards tumble rather than sliding flat', () {
        final c = ParticleController()
          ..shatterCell(const Offset(100, 100), palette.first, cell);
        final shard = c.particles.firstWhere((p) => p.spin != 0);
        final before = shard.angle;
        c.tick();
        expect(shard.angle, isNot(before));
      });

      test('reduce motion keeps the four quarters and trims only the chips', () {
        // The quarters are the effect. Halving them would leave a block that
        // broke into two, which is not what a reduced-motion player asked for.
        final c = ParticleController()
          ..reduceMotion = true
          ..shatterCell(const Offset(100, 100), palette.first, cell);
        expect(c.particles.where((p) => p.spin != 0).length, 4);
      });
    });

    testWidgets('400 live particles render through a single painter', (
      tester,
    ) async {
      final c = ParticleController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: bg,
            body: ParticleLayer(controller: c),
          ),
        ),
      );

      for (var i = 0; i < 64; i++) {
        c.burstCell(Offset(i * 3.0, i * 2.0), palette[i % palette.length], 40);
      }
      expect(c.particles.length, kMaxParticles);

      // One CustomPaint for the whole field, never one widget per particle.
      expect(find.byType(ParticleLayer), findsOneWidget);
      final painters = find.descendant(
        of: find.byType(ParticleLayer),
        matching: find.byType(CustomPaint),
      );
      expect(tester.widgetList(painters).length, 1);

      // Drive a second of animation at the cap without throwing.
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);
      expect(c.particles.length, lessThan(kMaxParticles));
    });
  });

  group('combo text', () {
    test('the streak ladder escalates and then holds', () {
      // A single clear is not a combo, so the ladder stays quiet at 1.
      expect(streakWord(0), isNull);
      expect(streakWord(1), isNull);
      expect(streakWord(2), 'Combo');
      expect(streakWord(3), 'Nice');
      expect(streakWord(4), 'Great');
      expect(streakWord(5), 'Excellent');
      expect(streakWord(6), 'Unstoppable');
      expect(streakWord(7), 'Legendary');
      // Holds at the top rather than running off the end of the list.
      expect(streakWord(40), 'Legendary');
    });

    test('every rung is reachable and none repeats', () {
      final seen = <String>{};
      for (var streak = kStreakWordFrom; streak < 40; streak++) {
        final w = streakWord(streak);
        expect(w, isNotNull);
        seen.add(w!);
      }
      expect(seen.length, kStreakWords.length);
      expect(seen, containsAll(kStreakWords));
    });

    testWidgets('floating text clears itself', (tester) async {
      final c = ComboTextController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ComboTextLayer(controller: c)),
        ),
      );
      c.showClear(const Offset(100, 100), 2, 40);
      c.showStreak(const Offset(100, 100), 4);
      expect(c.isEmpty, isFalse);

      // The animation is 900ms; a little past that leaves nothing behind.
      for (var frame = 0; frame < 70; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(c.isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
