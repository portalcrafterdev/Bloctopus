import 'package:flutter/material.dart';

/// Colours. Section 3 originally specified a dark scheme throughout; the owner
/// replaced it with this light one.
///
/// Only the *background* is light. The board, the tray and every chip stay
/// dark navy, because the block palette below has to stay readable and section
/// 7 requires the block colours never change. Light blocks on a light board
/// would force the palette to change, which is the one thing that must not
/// happen.

// Surfaces: sunlit water at the top of the game, deep water at the bottom.
const bg = Color(0xFF07518C); // scaffold: deep sea blue
const boardBg = Color(0xFF06395C); // board panel, the tray the squares sit in
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

// -- the sticker vocabulary ---------------------------------------------------
//
// What replaced the moulded "lip" under every button. A shape now reads as an
// object because it carries a white keyline and drops a hard shadow straight
// down, the way a sticker sits on glass. Depth comes from the offset, not from
// a second darker face, so nothing has to be derived from a fill colour and
// nothing can come out the wrong hue.

/// The white outline around a raised object.
const keyline = Color(0xFFFFFFFF);

/// The hard shadow under one. Not blurred: the whole look depends on its edge.
const stickerShadow = Color(0x47033C5C);

/// The primary action colour, top and bottom of its gradient, and the ink that
/// reads on it. Yellow carries every "go" in the game: Continue, Next level,
/// Resume, and the current node on the map.
const sunTop = Color(0xFFFFDE63);
const sunBottom = Color(0xFFFFAE1F);
const sunInk = Color(0xFF7A4A00);

/// The one warm accent that is not yellow, for destructive and alerting things.
const coral = Color(0xFFFF6B5E);

/// A translucent panel on the water. Light rather than dark, so it reads as
/// foam on the surface instead of a hole cut into it.
const panelFill = Color(0x2EFFFFFF);
const panelEdge = Color(0x59FFFFFF);

/// The well a board or tray sits in: darker water, not a lighter panel.
const wellFill = Color(0x47033C5C);

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
const inkTeal = Color(0xFF0FA9A0); // Blocktopus body on teal screens
const inkTealHi = Color(0xFF62E4D8); // Blocktopus highlight
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

/// The two faces, both SIL Open Font License, both in `assets/fonts/`.
///
/// [kDisplayFont] is Fredoka: rounded, geometric, and used for anything meant
/// to be read at a glance - the wordmark, headings, the score, button labels.
/// [kBodyFont] is Nunito, for copy a player actually reads: goal lines, the
/// tutorial, settings. The single face that used to do both jobs did the
/// second one badly.
///
/// Both are VARIABLE fonts, one file carrying a whole weight axis. Flutter
/// will not infer the axis from [TextStyle.fontWeight] alone, so every style
/// below also carries a matching [FontVariation], written out beside the weight
/// it must match. Together they are 436 KB, against the 1.6 MB of
/// the single Bagel Fat One they replace, because that one shipped a full
/// Hangul set the game never drew.
const String kDisplayFont = 'Fredoka';
const String kBodyFont = 'Nunito';

/// Text styles.
///
/// Section 3 allows 400, 500 and 600 only, and every style here holds to it.
/// Fredoka at 600 is already a heavy rounded face, so the weight the design
/// wants comes from the face rather than from a bolder cut.
class T {
  static const TextStyle display = TextStyle(
    fontFamily: kDisplayFont,
    color: textPrimary,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    letterSpacing: 0.2,
  );
  static const TextStyle title = TextStyle(
    fontFamily: kDisplayFont,
    color: textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
  );
  static const TextStyle heading = TextStyle(
    fontFamily: kDisplayFont,
    color: textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    fontVariations: <FontVariation>[FontVariation('wght', 500)],
  );
  static const TextStyle body = TextStyle(
    fontFamily: kBodyFont,
    color: textLilac,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    fontVariations: <FontVariation>[FontVariation('wght', 400)],
    height: 1.35,
  );
  static const TextStyle label = TextStyle(
    fontFamily: kBodyFont,
    color: textLilac,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontVariations: <FontVariation>[FontVariation('wght', 500)],
    letterSpacing: 0.3,
  );
  static const TextStyle dim = TextStyle(
    fontFamily: kBodyFont,
    color: textDim,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontVariations: <FontVariation>[FontVariation('wght', 400)],
  );
  static const TextStyle score = TextStyle(
    fontFamily: kDisplayFont,
    color: textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle accent = TextStyle(
    fontFamily: kDisplayFont,
    color: textAccent,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
  );
  static const TextStyle combo = TextStyle(
    fontFamily: kDisplayFont,
    color: textAccent,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
  );

  // -- on the light background, where there is no dark panel behind the text --

  static const TextStyle displayOnBg = TextStyle(
    fontFamily: kDisplayFont,
    color: textOnBg,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    letterSpacing: 0.2,
  );
  static const TextStyle titleOnBg = TextStyle(
    fontFamily: kDisplayFont,
    color: textOnBg,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
  );
  static const TextStyle headingOnBg = TextStyle(
    fontFamily: kBodyFont,
    color: textOnBg,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    fontVariations: <FontVariation>[FontVariation('wght', 500)],
  );
  static const TextStyle labelOnBg = TextStyle(
    fontFamily: kBodyFont,
    color: textOnBgDim,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontVariations: <FontVariation>[FontVariation('wght', 500)],
    letterSpacing: 0.3,
  );
  static const TextStyle dimOnBg = TextStyle(
    fontFamily: kBodyFont,
    color: textOnBgDim,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontVariations: <FontVariation>[FontVariation('wght', 400)],
  );
  static const TextStyle scoreOnBg = TextStyle(
    fontFamily: kDisplayFont,
    color: textOnBg,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
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
    [Color(0xFF0F2D56), Color(0xFF0B203D)], // 16 Hadal Reach
    [Color(0xFF0F2953), Color(0xFF0A1D3A)], // 17 Black Smoker
    [Color(0xFF0E264F), Color(0xFF0A1A37)], // 18 Drowned Spire
    [Color(0xFF0E234C), Color(0xFF0A1834)], // 19 Glass Forest
    [Color(0xFF0E2049), Color(0xFF091531)], // 20 Still Water
  ];
  return stops[(chapter - 1).clamp(0, stops.length - 1)];
}

/// The home screen's own descent: sunlit water at the top, deep water at the
/// bottom, ending on exactly [bg] so the screen and the scaffold behind it are
/// continuous.
///
/// It runs light to dark, which is the reverse of what it used to do. The
/// whole game now descends the same way the chapters do.
///
/// The top stop is deeper than the design mockup's turquoise, and deliberately
/// so: white on that turquoise measured 1.66:1, against the 4.5:1 WCAG asks
/// for body text, which is unreadable outdoors. Every stop here clears 4.5,
/// and `theme_contrast_test.dart` holds it to that.
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
      primary: inkPurple,
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
