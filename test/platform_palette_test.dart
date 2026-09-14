import 'dart:io';

import 'package:blocktopus/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Three files outside `lib/` keep their own copy of the palette, and none of
/// them can import `theme.dart`: `tool/generate_icon.dart` is pure Dart so it
/// can run without Flutter, and the Android resources are XML.
///
/// The copies are the problem. Both drifted and stayed drifted - the app moved
/// from the near-black of section 3 to violet and then to water, while the
/// icon stayed a purple octopus on `0xFF141026` and the launch window stayed
/// violet. Neither fails at build time. The icon generator runs happily and
/// writes valid PNGs; the launch window is simply the wrong colour for the
/// third of a second before Flutter draws, which reads as a flash and is very
/// easy to blame on something else.
///
/// So the copies are compared here. This does not check that the icons on disk
/// were regenerated after an edit - it checks that running the generator would
/// produce the right colours, which is the half that cannot be seen by eye.
void main() {
  group('the launcher icon', () {
    final source = File('tool/generate_icon.dart').readAsStringSync();

    /// Reads `const int _name = 0xAARRGGBB;` out of the generator.
    int constant(String name) {
      final m = RegExp(
        'const int $name = (0x[0-9A-Fa-f]{8});',
      ).firstMatch(source);
      expect(m, isNotNull, reason: '$name is gone from the icon generator');
      return int.parse(m!.group(1)!);
    }

    test('draws the mascot the game draws', () {
      expect(
        constant('_inkTeal'),
        inkTeal.toARGB32(),
        reason: 'the icon body colour is not the mascot body colour',
      );
      expect(
        constant('_inkTealHi'),
        inkTealHi.toARGB32(),
        reason: 'the icon highlight is not the mascot highlight',
      );
      expect(constant('_inkPink'), inkPink.toARGB32());
    });

    test('sits on the background the game sits on', () {
      // Section 13 asks for the mascot head, flat, on `bg`. This is the value
      // that went stale, and it is the most visible one: it is the whole
      // field of the icon.
      expect(
        constant('_bg'),
        bg.toARGB32(),
        reason: 'the icon background is not the scaffold colour',
      );
    });

    test('separates the mascot from the field behind him', () {
      // The icon is the one place the mascot is drawn with no gradient and no
      // shadow to help him, so the flat pair has to carry it alone. Small
      // sizes are the real test: a 48px mipmap loses every detail except this.
      double relative(int argb) => Color(argb).computeLuminance() + 0.05;
      final head = relative(constant('_inkTeal'));
      final field = relative(constant('_bg'));
      expect(
        head > field ? head / field : field / head,
        greaterThanOrEqualTo(3),
        reason: 'the octopus disappears into his own icon',
      );
    });
  });

  group('the Android launch window', () {
    test('opens on the colour the app opens on', () {
      // What the player sees between tapping the icon and the first Flutter
      // frame. Wrong, it is a coloured flash on every cold start; right, the
      // handover is invisible, which is the whole point of setting it.
      final xml = File(
        'android/app/src/main/res/values/colors.xml',
      ).readAsStringSync();
      final m = RegExp(
        r'<color name="blocktopus_bg">#([0-9A-Fa-f]{8})</color>',
      ).firstMatch(xml);
      expect(m, isNotNull, reason: 'blocktopus_bg is gone from colors.xml');

      expect(
        int.parse(m!.group(1)!, radix: 16),
        bg.toARGB32(),
        reason: 'the launch window flashes a colour the game does not use',
      );
    });
  });
}
