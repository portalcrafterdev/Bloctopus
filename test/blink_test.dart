import 'dart:math';

import 'package:blocktopus/widgets/mascot_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mascot's blink used to be driven off a clock that wrapped every ten
/// seconds, and compared against a future time. Both halves broke at the wrap:
/// a blink scheduled just past it fired on the very next frame, so instead of
/// blinking every few seconds he stuttered his eyes several times a second;
/// and a blink that started near the end of a cycle stayed shut for most of
/// the following one.
///
/// These run the schedule at 60fps over a minute, well past where the old
/// clock would have wrapped six times.
const double _frame = 1 / 60;

/// Runs the clock for [seconds] and returns the start time of every blink.
List<double> blinkStarts(BlinkClock clock, double seconds) {
  final starts = <double>[];
  var wasBlinking = false;
  for (var t = 0.0; t < seconds; t += _frame) {
    clock.update(t);
    if (clock.isBlinking && !wasBlinking) starts.add(t);
    wasBlinking = clock.isBlinking;
  }
  return starts;
}

void main() {
  test('blinks land 3 to 6 seconds apart, for a whole minute', () {
    final clock = BlinkClock(random: Random(7));
    final starts = blinkStarts(clock, 60);

    // 60 seconds at one blink every 3 to 6 seconds, and each blink itself
    // eats 0.18s of the gap.
    expect(starts.length, inInclusiveRange(9, 20));

    for (var i = 1; i < starts.length; i++) {
      final gap = starts[i] - starts[i - 1];
      expect(
        gap,
        greaterThanOrEqualTo(BlinkClock.minGap),
        reason: 'blink $i came ${gap.toStringAsFixed(2)}s after the last one',
      );
      expect(
        gap,
        lessThanOrEqualTo(
          BlinkClock.maxGap + BlinkClock.closeSeconds + _frame * 2,
        ),
        reason: 'blink $i came ${gap.toStringAsFixed(2)}s after the last one',
      );
    }
  });

  test('the gaps actually vary, so he does not blink on a metronome', () {
    final starts = blinkStarts(BlinkClock(random: Random(3)), 60);
    final gaps = <double>[
      for (var i = 1; i < starts.length; i++) starts[i] - starts[i - 1],
    ];
    expect(gaps.toSet().length, greaterThan(3));
  });

  test('a blink shuts and opens again rather than snapping', () {
    final clock = BlinkClock(random: Random(1));
    // Step to just after the first blink begins.
    var t = 0.0;
    while (!clock.isBlinking) {
      t += _frame;
      clock.update(t);
    }
    final start = t;

    final samples = <double>[];
    for (var i = 0; i <= 12; i++) {
      final at = start + BlinkClock.closeSeconds * i / 12;
      samples.add(clock.amount(at));
    }

    expect(samples.first, lessThan(0.2), reason: 'starts open');
    expect(samples.reduce(max), greaterThan(0.95), reason: 'fully shuts');
    expect(samples.last, lessThan(0.2), reason: 'ends open again');

    // Shuts faster than it opens: the peak sits in the first half.
    final peak = samples.indexOf(samples.reduce(max));
    expect(peak, lessThan(samples.length / 2));
  });

  test('the eye is open whenever no blink is running', () {
    final clock = BlinkClock(random: Random(5));
    for (var t = 0.0; t < 20; t += _frame) {
      clock.update(t);
      if (!clock.isBlinking) {
        expect(clock.amount(t), 0, reason: 'stray lid at ${t}s');
      }
    }
  });

  testWidgets('the mascot keeps blinking well past the old clock wrap', (
    tester,
  ) async {
    // End to end, at the size he is drawn on the map. The old ten second wrap
    // is crossed three times here.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: MascotView(size: 96, state: MascotState.idle)),
        ),
      ),
    );
    for (var i = 0; i < 35 * 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
  });
}
