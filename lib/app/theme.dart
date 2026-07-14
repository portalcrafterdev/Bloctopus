import 'package:flutter/material.dart';

/// Colours. Section 3 originally specified a dark scheme throughout; the owner
/// replaced it with this light one.
///
/// Only the *background* is light. The board, the tray and every chip stay
/// dark navy, because the block palette below has to stay readable and section
/// 7 requires the block colours never change. Light blocks on a light board
/// would force the palette to change, which is the one thing that must not
/// happen.

// Surfaces
const bg = Color(0xFF8259C6); // scaffold: open violet
const boardBg = Color(0xFF4A3E7E); // board panel
const cellEmpty = Color(0xFF5B4E94); // empty cell, light square
const cellEmptyAlt = Color(0xFF524589); // empty cell, dark square
const border = Color(0xFF6858A4); // panel borders
const chipBorder = Color(0xFF6858A4); // buttons

/// A dark veil for anything that has to dim what is behind it. `bg` cannot do
/// this job: it is a mid tone, so using it to dim a panel would lighten it.
const scrim = Color(0xFF2A1F52);

// Text on the panels.
const textPrimary = Color(0xFFFFFFFF);
const textLilac = Color(0xFFE0D6F6);
const textDim = Color(0xFFBCAEE4);
const textAccent = Color(0xFFFFC24D);

// Text sitting straight on the background with no panel behind it. The
// background is a mid violet, dark enough to carry white, which is why these
// are light rather than dark. `theme_contrast_test.dart` holds them to it
// against every chapter gradient, not just the flat colour.
const textOnBg = Color(0xFFFFFFFF);
const textOnBgDim = Color(0xFFEBE2FB);

/// Block palette, picked at random per piece.
///
/// Saturated on purpose. These sit on a violet board, and the muted originals
/// from section 3 were tuned for a near-black one: the same colours that read
/// as calm on black read as washed out on purple. Each one is held to a
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

// Mascot
const inkPurple = Color(0xFF8B5CF0); // Blocktopus body
const inkPurpleHi = Color(0xFFB47CF5); // highlight
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

/// Text styles. Only weights 400, 500 and 600 are allowed.
class T {
  static const TextStyle display = TextStyle(
    color: textPrimary,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
  static const TextStyle title = TextStyle(
    color: textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle heading = TextStyle(
    color: textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle body = TextStyle(
    color: textLilac,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );
  static const TextStyle label = TextStyle(
    color: textLilac,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );
  static const TextStyle dim = TextStyle(
    color: textDim,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle score = TextStyle(
    color: textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle accent = TextStyle(
    color: textAccent,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle combo = TextStyle(
    color: textAccent,
    fontSize: 26,
    fontWeight: FontWeight.w600,
  );

  // -- on the light background, where there is no dark panel behind the text --

  static const TextStyle displayOnBg = TextStyle(
    color: textOnBg,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
  static const TextStyle titleOnBg = TextStyle(
    color: textOnBg,
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle headingOnBg = TextStyle(
    color: textOnBg,
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle labelOnBg = TextStyle(
    color: textOnBgDim,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );
  static const TextStyle dimOnBg = TextStyle(
    color: textOnBgDim,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle scoreOnBg = TextStyle(
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
    [Color(0xFF7E4FBE), Color(0xFF5E3A9A)], // 1  Tide Pools
    [Color(0xFF7355C0), Color(0xFF55409C)], // 2  Kelp Forest
    [Color(0xFF864CBC), Color(0xFF663598)], // 3  Coral Shelf
    [Color(0xFF7A4ABA), Color(0xFF5A3596)], // 4  Wreck Reef
    [Color(0xFF8B52C6), Color(0xFF6B3CA2)], // 5  Jelly Drift
    [Color(0xFF6F4CB0), Color(0xFF51378C)], // 6  Stone Trench
    [Color(0xFF9152C8), Color(0xFF6F3BA4)], // 7  Bloom Deep
    [Color(0xFF6650B8), Color(0xFF4A3A94)], // 8  Cold Current
    [Color(0xFF6A4CAA), Color(0xFF4E3786)], // 9  Basalt Maze
    [Color(0xFF5A44A0), Color(0xFF40307C)], // 10 Abyss
    [Color(0xFF7040B4), Color(0xFF522C90)], // 11 Ink Depths I
    [Color(0xFF733CB4), Color(0xFF552890)], // 12 Ink Depths II
    [Color(0xFF7738B4), Color(0xFF582490)], // 13 Ink Depths III
    [Color(0xFF7A34B4), Color(0xFF5C2090)], // 14 Ink Depths IV
    [Color(0xFF7E30B4), Color(0xFF5F1C90)], // 15 Ink Depths V
  ];
  return stops[(chapter - 1).clamp(0, stops.length - 1)];
}

/// The home screen's own descent, and the one place in the game that runs
/// dark to light rather than the other way round.
///
/// The scattered blocks behind the title need a deep top to read as depth, and
/// the buttons need a lit bottom to sit on. It ends on exactly [bg] so the
/// screen and the scaffold behind it are continuous.
/// `theme_contrast_test.dart` holds white text to every stop.
const List<Color> homeGradient = <Color>[
  Color(0xFF3A2568),
  Color(0xFF55379A),
  Color(0xFF6E48B4),
  bg,
];

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.light(
      surface: bg,
      primary: inkPurple,
      secondary: textAccent,
    ),
    fontFamily: null,
    splashFactory: NoSplash.splashFactory,
    textTheme: const TextTheme(
      bodyMedium: T.body,
      titleMedium: T.heading,
      titleLarge: T.title,
    ),
  );
}
