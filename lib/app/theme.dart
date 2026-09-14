import 'package:flutter/material.dart';

/// Colours. Section 3 originally specified a near-black scheme throughout; the
/// owner replaced it, first with violet and now with this ocean one.
///
/// The background is water, lit at the top of the screen and deep at the
/// bottom. The board, the tray and every chip stay darker than it, because the
/// block palette below has to stay readable and section 7 requires the block
/// colours never change. A board as light as its background would force the
/// palette to change, which is the one thing that must not happen.

// Surfaces: sunlit water at the top of the game, deep water at the bottom.
const bg = Color(0xFF07518C); // scaffold: deep sea blue
const boardBg = Color(0xFF06395C); // board panel
const cellEmpty = Color(0xFF084667); // empty cell, light square
const cellEmptyAlt = Color(0xFF07405E); // empty cell, dark square
const border = Color(0xFF2E7FA8); // panel borders
const chipBorder = Color(0xFF2E7FA8); // buttons

/// A dark veil for anything that has to dim what is behind it. `bg` cannot do
/// this job: it is a mid tone, so using it to dim a panel would lighten it.
const scrim = Color(0xFF032A4D);

// Text on the panels.
const textPrimary = Color(0xFFFFFFFF);
const textLilac = Color(0xFFCFE9F5);
const textDim = Color(0xFF9CC8DC);
const textAccent = Color(0xFFFFD23F);

// Text sitting straight on the background with no panel behind it. The
// background is deep water, dark enough to carry white, which is why these
// are light rather than dark. `theme_contrast_test.dart` holds them to it
// against every chapter gradient, not just the flat colour.
const textOnBg = Color(0xFFFFFFFF);
const textOnBgDim = Color(0xFFD9EFFA);

/// Block palette, picked at random per piece.
///
/// Saturated on purpose. These sit on a deep blue board, and the muted originals
/// from section 3 were tuned for a near-black one: the same colours that read
/// as calm on black read as washed out on water. Each one is held to a
/// minimum separation from both board squares and from every other block by
/// `theme_contrast_test.dart`.
///
/// The pink deliberately avoids the red of [ghostInvalid]. An invalid drop
/// hint that looks like an ordinary block is worse than no hint.
const palette = <Color>[
  Color(0xFF3D9BFF), // blue
  Color(0xFF46DC5A), // green
  Color(0xFFFFC61F), // gold
  Color(0xFFF857C2), // magenta
  Color(0xFFC77DFF), // violet
  Color(0xFF2FE3D5), // cyan
  Color(0xFFFF6B18), // orange
];

// Mascot. Section 3 and section 9 both call Blocktopus purple; the owner
// wants him teal, which is the harder ask of the two, because the sea behind
// him is now teal as well.
//
// So the separation has to come from lightness rather than hue, and the value
// is picked against the *lightest* thing he is ever drawn on - the top stop of
// [homeGradient], where he sits on the home screen. This one clears it at
// 2.3:1. The deeper teals that look better in isolation do not: 0xFF0FA9A0
// lands at 1.75 and 0xFF0E8F88 at 1.29, which is an octopus-shaped hole in
// the water rather than an octopus.
//
// It stays a step off the palette's cyan block, so a mascot on the map is
// never mistaken for a piece.
const inkTeal = Color(0xFF19C2B4); // Blocktopus body
const inkTealHi = Color(0xFF57E3D4); // highlight
const inkPink = Color(0xFFFF9AC1); // suckers, cheeks

/// Ghost colours.
const ghostInvalid = Color(0xFFFF5D7A);

/// Blocked cells are permanent scenery, not blocks. They read as dark stone.
const cellBlocked = Color(0xFF3E3570);

/// Cell geometry, expressed as fractions of the cell size.
const double kCellRadiusFactor = 0.22;
const double kCellInsetFactor = 0.06;
const double kGlossRadiusFactor = 0.12;

/// The dragged piece sits this many cell heights above the finger.
const double kDragLiftFactor = 1.4;

Color paletteColor(int index) => palette[index % palette.length];

/// The game's face: Bagel Fat One, SIL Open Font License, see `assets/fonts/`.
///
/// Everything, by the owner's decision - every style below carries it, and
/// [buildTheme] sets it app wide so a widget that never touches [T] matches
/// too. It is a display face used as a text face, which is a deliberate
/// choice with two consequences worth knowing.
///
/// It is very round and very heavy, so it is much wider than the platform
/// font at the same size. Anything measured against a fixed band - the map's
/// chapter banner, the two play keys, the booster chips - has less room than
/// it used to, and `layout_test.dart` is what catches that, across four
/// screen sizes.
///
/// It also carries a full Hangul set, which is why the file is 1.6 MB against
/// the 80 KB of the Arbutus it replaced. The game draws none of it. That is
/// still well inside section 2's 40 MB budget, but subsetting the font to the
/// characters actually used would reclaim nearly all of it.
///
/// One weight, which is the whole point of picking a display face rather than
/// a heavier weight of a text font: section 3 allows nothing above 600, and
/// this carries the heft without breaking that.
const String kDisplayFont = 'BagelFatOne';

/// Text styles. Only weights 400, 500 and 600 are allowed.
class T {
  static const TextStyle display = TextStyle(
    fontFamily: kDisplayFont,
    color: textPrimary,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
  static const TextStyle title = TextStyle(
    fontFamily: kDisplayFont,
    color: textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle heading = TextStyle(
    fontFamily: kDisplayFont,
    color: textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle body = TextStyle(
    fontFamily: kDisplayFont,
    color: textLilac,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );
  static const TextStyle label = TextStyle(
    fontFamily: kDisplayFont,
    color: textLilac,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );
  static const TextStyle dim = TextStyle(
    fontFamily: kDisplayFont,
    color: textDim,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle score = TextStyle(
    fontFamily: kDisplayFont,
    color: textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle accent = TextStyle(
    fontFamily: kDisplayFont,
    color: textAccent,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle combo = TextStyle(
    fontFamily: kDisplayFont,
    color: textAccent,
    fontSize: 26,
    fontWeight: FontWeight.w600,
  );

  // -- on the light background, where there is no dark panel behind the text --

  static const TextStyle displayOnBg = TextStyle(
    fontFamily: kDisplayFont,
    color: textOnBg,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
  static const TextStyle titleOnBg = TextStyle(
    fontFamily: kDisplayFont,
    color: textOnBg,
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle headingOnBg = TextStyle(
    fontFamily: kDisplayFont,
    color: textOnBg,
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle labelOnBg = TextStyle(
    fontFamily: kDisplayFont,
    color: textOnBgDim,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );
  static const TextStyle dimOnBg = TextStyle(
    fontFamily: kDisplayFont,
    color: textOnBgDim,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle scoreOnBg = TextStyle(
    fontFamily: kDisplayFont,
    color: textOnBg,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Per-chapter background gradient. Chapter themes change only the map banner
/// and the background gradient. Block colours never change.
/// The ocean still descends, it just descends through a lit sea rather than a
/// dark one: chapter 1 is bright shallows, chapter 15 is deep water. Light
/// enough throughout that the dark board reads as an object sitting on it.
List<Color> chapterGradient(int chapter) {
  const stops = <List<Color>>[
    [Color(0xFF0F798A), Color(0xFF0C5F6C)], //  1 Tide Pools
    [Color(0xFF0F7386), Color(0xFF0C5969)], //  2 Kelp Forest
    [Color(0xFF106C82), Color(0xFF0C5465)], //  3 Coral Shelf
    [Color(0xFF10667F), Color(0xFF0C4F62)], //  4 Wreck Reef
    [Color(0xFF10607B), Color(0xFF0C4A5F)], //  5 Jelly Drift
    [Color(0xFF105A78), Color(0xFF0C455C)], //  6 Stone Trench
    [Color(0xFF105574), Color(0xFF0C4159)], //  7 Bloom Deep
    [Color(0xFF105071), Color(0xFF0C3C55)], //  8 Cold Current
    [Color(0xFF104B6D), Color(0xFF0C3852)], //  9 Basalt Maze
    [Color(0xFF10466A), Color(0xFF0C344F)], // 10 Abyss
    [Color(0xFF104167), Color(0xFF0C304C)], // 11 Ink Depths I
    [Color(0xFF0F3D63), Color(0xFF0B2D49)], // 12 Ink Depths II
    [Color(0xFF0F3860), Color(0xFF0B2946)], // 13 Ink Depths III
    [Color(0xFF0F345C), Color(0xFF0B2643)], // 14 Ink Depths IV
    [Color(0xFF0F3059), Color(0xFF0B2340)], // 15 Ink Depths V
    // 16-20. The descent simply keeps going. Every stop walks the same line
    // from teal shallows towards near-black blue, cooling and darkening a
    // fixed step at a time, so the twenty chapters read as one dive rather
    // than as five palettes stitched together.
    [Color(0xFF0F2D56), Color(0xFF0B203D)], // 16 Hadal Reach
    [Color(0xFF0F2953), Color(0xFF0A1D3A)], // 17 Black Smoker
    [Color(0xFF0E264F), Color(0xFF0A1A37)], // 18 Drowned Spire
    [Color(0xFF0E234C), Color(0xFF0A1834)], // 19 Glass Forest
    [Color(0xFF0E2049), Color(0xFF091531)], // 20 Still Water
  ];
  return stops[(chapter - 1).clamp(0, stops.length - 1)];
}

/// The home screen's own descent: the surface of the water at the top of the
/// screen, open sea by the bottom.
///
/// It runs light to dark, the same direction as every chapter gradient, so the
/// first screen a player sees is the shallowest water in the game and the dive
/// starts from there. It ends on exactly [bg] so the screen and the scaffold
/// behind it are continuous.
/// `theme_contrast_test.dart` holds white text to every stop.
const List<Color> homeGradient = <Color>[
  Color(0xFF0F798A),
  Color(0xFF0C6A88),
  Color(0xFF0A5E8E),
  bg,
];

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.light(
      surface: bg,
      primary: inkTeal,
      secondary: textAccent,
    ),
    // App wide, so a widget that never touches [T] - a SnackBar, a
    // TextButton, a Material default - is set in the same face as everything
    // around it.
    fontFamily: kDisplayFont,
    splashFactory: NoSplash.splashFactory,
    textTheme: const TextTheme(
      bodyMedium: T.body,
      titleMedium: T.heading,
      titleLarge: T.title,
    ),
  );
}
