import 'package:blocktopus/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the light theme against the failure it kept producing: a colour that
/// used to mean "dark" quietly became light, and something drawn on it turned
/// invisible. It happened to the blast dim, the tutorial scrim, the combo text
/// outline and the result sheet's Map button, each found by eye, one at a time.
///
/// Contrast ratios are WCAG: (lighter + 0.05) / (darker + 0.05), 1 to 21.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// 4.5 is the WCAG AA threshold for body text.
const double kBodyText = 4.5;

/// 3.0 is AA for large text, and the floor for anything that only has to be
/// distinguishable rather than readable.
const double kLargeText = 3;

/// Degrees between two hues on the colour wheel, 0 to 180.
double _hueGap(Color a, Color b) {
  final ha = HSLColor.fromColor(a).hue;
  final hb = HSLColor.fromColor(b).hue;
  final d = (ha - hb).abs() % 360;
  return d > 180 ? 360 - d : d;
}

void main() {
  group('surfaces are ordered the way the design depends on', () {
    test('the board sits darker than the background it lies on', () {
      // The board has to read as an object on the backdrop, not as a hole in
      // it, and the blocks need a darker field than the sky behind them.
      expect(boardBg.computeLuminance(), lessThan(bg.computeLuminance()));
      expect(cellEmpty.computeLuminance(), lessThan(bg.computeLuminance()));
    });

    test('the two empty cell shades differ, but only just', () {
      // A checkerboard, not a chessboard: enough to see the grid, not enough
      // to compete with the blocks sitting on it.
      final a = cellEmpty.computeLuminance();
      final b = cellEmptyAlt.computeLuminance();
      expect(a, isNot(closeTo(b, 0.002)), reason: 'the squares are identical');
      expect(contrast(cellEmpty, cellEmptyAlt), lessThan(1.4));
    });

    test('the scrim really can dim everything it covers', () {
      // The whole point of `scrim` existing. If it ever stops being darker
      // than what it covers, every overlay in the game inverts.
      for (final surface in <Color>[bg, boardBg, cellEmpty]) {
        expect(
          scrim.computeLuminance(),
          lessThan(surface.computeLuminance()),
          reason: 'the scrim would brighten $surface',
        );
      }
    });
  });

  group('text is readable on what it sits on', () {
    test('on-light text against the flat background', () {
      expect(contrast(textOnBg, bg), greaterThanOrEqualTo(kBodyText));
      expect(contrast(textOnBgDim, bg), greaterThanOrEqualTo(kLargeText));
    });

    test('on-light text against every chapter gradient', () {
      // The score header and the map banner sit on the gradient, not on the
      // flat `bg`, and the gradient is different in all fifteen chapters.
      for (var chapter = 1; chapter <= 15; chapter++) {
        for (final stop in chapterGradient(chapter)) {
          expect(
            contrast(textOnBg, stop),
            greaterThanOrEqualTo(kBodyText),
            reason: 'chapter $chapter stop $stop',
          );
          expect(
            contrast(textOnBgDim, stop),
            greaterThanOrEqualTo(kLargeText),
            reason: 'chapter $chapter stop $stop',
          );
        }
      }
    });

    test('on-light text against the home gradient', () {
      // Home is the one screen that runs dark to light, so it is the one place
      // where making the bottom "a bit brighter" quietly breaks white text.
      for (final stop in homeGradient) {
        expect(
          contrast(textOnBg, stop),
          greaterThanOrEqualTo(kBodyText),
          reason: 'home stop $stop',
        );
        expect(
          contrast(textOnBgDim, stop),
          greaterThanOrEqualTo(kLargeText),
          reason: 'home stop $stop',
        );
      }
    });

    test('the home gradient really does descend into the scaffold', () {
      // Its whole shape: deep at the top, ending on `bg` so the screen and the
      // scaffold behind it are continuous.
      for (var i = 1; i < homeGradient.length; i++) {
        expect(
          homeGradient[i].computeLuminance(),
          greaterThan(homeGradient[i - 1].computeLuminance()),
          reason: 'stop $i is not lighter than the one above it',
        );
      }
      expect(homeGradient.last, bg);
    });

    test('panel text against the dark panels', () {
      // `cellEmpty` is deliberately not in this list. It is a board square,
      // and no text is ever drawn on one.
      for (final panel in <Color>[boardBg, scrim]) {
        expect(
          contrast(textPrimary, panel),
          greaterThanOrEqualTo(kBodyText),
          reason: 'primary on $panel',
        );
        expect(
          contrast(textLilac, panel),
          greaterThanOrEqualTo(kLargeText),
          reason: 'lilac on $panel',
        );
        expect(
          contrast(textDim, panel),
          greaterThanOrEqualTo(kLargeText),
          reason: 'dim on $panel',
        );
        expect(
          contrast(textAccent, panel),
          greaterThanOrEqualTo(kLargeText),
          reason: 'accent on $panel',
        );
      }
    });

    test('white on the filled button colour', () {
      expect(
        contrast(textPrimary, inkPurple),
        greaterThanOrEqualTo(kLargeText),
      );
    });

    test('the styles use the colours their names promise', () {
      // A style named "OnBg" carrying white text is the exact mistake this
      // file exists to catch, and it is invisible in a golden built from boxes.
      for (final style in <TextStyle>[
        T.displayOnBg,
        T.titleOnBg,
        T.headingOnBg,
        T.labelOnBg,
        T.dimOnBg,
        T.scoreOnBg,
      ]) {
        expect(
          contrast(style.color!, bg),
          greaterThanOrEqualTo(kLargeText),
          reason: 'an on-light style is not readable on the background',
        );
      }
      for (final style in <TextStyle>[
        T.display,
        T.title,
        T.heading,
        T.body,
        T.label,
        T.dim,
        T.score,
      ]) {
        expect(
          contrast(style.color!, boardBg),
          greaterThanOrEqualTo(kLargeText),
          reason: 'a panel style is not readable on a panel',
        );
      }
    });
  });

  group('blocks stay readable against the board', () {
    /// Blocks are not text. Each one fills most of its square, carries a
    /// darker bevel wall all the way round and drops a shadow, so it separates
    /// from the board by shape and depth as well as by colour. The bar is
    /// therefore "clearly a different thing", not the AA reading threshold.
    const double kBlockOnBoard = 2;

    test('every block colour separates from both empty squares', () {
      for (final block in palette) {
        for (final square in <Color>[cellEmpty, cellEmptyAlt]) {
          expect(
            contrast(block, square),
            greaterThanOrEqualTo(kBlockOnBoard),
            reason: '$block is lost against $square',
          );
        }
      }
    });

    test('blocked cells read as scenery, not as a block', () {
      // Section 6.2: blocked cells are permanent and must not be mistaken for
      // something placeable, so they stay close to the empty cell and far from
      // every block colour.
      expect(contrast(cellBlocked, cellEmpty), lessThan(kLargeText));
      for (final block in palette) {
        expect(
          contrast(block, cellBlocked),
          greaterThan(1.4),
          reason: '$block is indistinguishable from a blocked cell',
        );
      }
    });

    test('the invalid ghost stands out on the board', () {
      expect(contrast(ghostInvalid, cellEmpty), greaterThan(kBlockOnBoard));
      expect(contrast(ghostInvalid, cellEmptyAlt), greaterThan(kBlockOnBoard));
    });

    test('no block is mistakable for the invalid drop hint', () {
      // The hint means "you cannot put it there". A block that shares its hue
      // turns that into a guess, so keep every block a clear hue away from it.
      for (final block in palette) {
        expect(
          _hueGap(block, ghostInvalid),
          greaterThan(18),
          reason: '$block is the same hue as the invalid hint',
        );
      }
    });

    test('the blocks are told apart by hue, not only by lightness', () {
      // Seven colours picked at random per piece. Two that differ only in
      // brightness are the same block to a player glancing at the tray, and
      // to anyone with a colour vision deficiency they may be identical.
      for (var i = 0; i < palette.length; i++) {
        for (var j = i + 1; j < palette.length; j++) {
          expect(
            _hueGap(palette[i], palette[j]),
            greaterThan(20),
            reason: 'blocks $i and $j are too close in hue',
          );
        }
      }
    });
  });
}
