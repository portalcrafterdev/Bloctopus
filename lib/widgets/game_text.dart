import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Chunky arcade lettering: a dark outline, a gradient face and a hard shadow.
///
/// The look every casual puzzle game uses for the words it wants read from
/// across a room. It is the same string drawn several times:
///
///   1. a shadow pass, stroked and filled in one dark colour and offset down,
///      so the letters sit on something rather than floating
///   2. an outline pass, stroked in [outline]
///   3. the face, filled with a vertical gradient
///
/// Several draws rather than [TextStyle.shadows] because a shadow list blurs
/// and softens, and this look depends on hard edges. A [TextStyle] may carry
/// `color` or `foreground`, never both, so a stroked and filled glyph is
/// always more than one draw.
///
/// The passes underneath are painted rather than stacked as widgets. Four
/// [Text] widgets showing the same string is four times the layout work, and
/// worse, four things in the tree: a screen reader read every heading four
/// times over, and `find.text` in a widget test matched four candidates where
/// the screen shows one word. So only the face is a real [Text] - it carries
/// the semantics and it is what a test finds - and the shadow and outline are
/// drawn behind it by [_BackingPainter], which lays the string out exactly the
/// same way so the two cannot drift apart.
///
/// The weight comes from the stroke, not from the face. Section 3 allows 400,
/// 500 and 600 only, and a heavier face is the obvious way to get this look
/// and the one that is not available - so the stroke does that work, which is
/// also what keeps the letters legible on a light background.
class GameText extends StatelessWidget {
  final String text;
  final double fontSize;

  /// The face, top colour first. A single entry fills flat.
  final List<Color> colors;

  final Color outline;

  /// Stroke width and shadow drop, both as a fraction of [fontSize], so the
  /// look holds at any size rather than needing to be retuned per use.
  final double outlineScale;
  final double shadowScale;

  final Color shadowColor;
  final TextAlign textAlign;
  final double letterSpacing;

  /// Applied to the face and to the painted passes alike. They must agree: a
  /// backing pass that wrapped where the face ellipsed would draw an outline
  /// around letters that are not there.
  final int? maxLines;
  final TextOverflow? overflow;

  const GameText(
    this.text, {
    super.key,
    this.fontSize = 34,
    this.colors = gold,
    this.outline = scrim,
    this.outlineScale = 0.15,
    this.shadowScale = 0.06,
    this.shadowColor = const Color(0x66000000),
    this.textAlign = TextAlign.center,
    this.letterSpacing = 0.6,
    this.maxLines,
    this.overflow,
  });

  /// The warm gold of the reference: the default, and what the game already
  /// uses for anything it wants looked at.
  static const List<Color> gold = <Color>[Color(0xFFFFE08A), Color(0xFFFFA51F)];

  /// The mascot's own violet, for headings that sit on a light surface.
  static const List<Color> violet = <Color>[
    Color(0xFFC9A6FF),
    Color(0xFF7A4FE0),
  ];

  static const List<Color> mint = <Color>[Color(0xFFBFF7C8), Color(0xFF3FBF6A)];

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: letterSpacing,
      height: 1.06,
    );

    final face = Text(
      text,
      style: style.copyWith(color: colors.first),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );

    return CustomPaint(
      painter: _BackingPainter(
        text: text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        ellipsis: overflow == TextOverflow.ellipsis,
        strokeWidth: fontSize * outlineScale,
        drop: fontSize * shadowScale,
        outline: outline,
        shadowColor: shadowColor,
      ),
      child: colors.length > 1
          ? ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ).createShader(rect),
              child: face,
            )
          : face,
    );
  }
}

/// Draws the shadow and outline behind [GameText]'s face.
///
/// Lays the string out with the same style, alignment and line limit as the
/// face, against the same width, so the two land on the same pixels. The
/// painter is sized by its child, which is that face, so the box it is given
/// is exactly the box the face occupies.
class _BackingPainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final int? maxLines;
  final bool ellipsis;
  final double strokeWidth;
  final double drop;
  final Color outline;
  final Color shadowColor;

  const _BackingPainter({
    required this.text,
    required this.style,
    required this.textAlign,
    required this.maxLines,
    required this.ellipsis,
    required this.strokeWidth,
    required this.drop,
    required this.outline,
    required this.shadowColor,
  });

  TextPainter _painterFor(Paint? stroke, Color? fill, double width) {
    return TextPainter(
      text: TextSpan(
        text: text,
        // Built rather than copied: copyWith cannot drop a colour, and a
        // style may carry `color` or `foreground`, never both.
        style: TextStyle(
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          letterSpacing: style.letterSpacing,
          height: style.height,
          color: fill,
          foreground: stroke,
        ),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: ellipsis ? '…' : null,
    )..layout(maxWidth: width);
  }

  Paint _stroke(Color colour) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    // Round joins, or every corner of every letter grows a spike at this
    // stroke width.
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = colour;

  @override
  void paint(Canvas canvas, Size size) {
    // The shadow is the whole silhouette - outline included - dropped straight
    // down. Offsetting only the face would leave it peeking out from under the
    // outline instead of sitting behind the letter.
    final shadowOffset = Offset(0, drop);
    _painterFor(_stroke(shadowColor), null, size.width)
        .paint(canvas, shadowOffset);
    _painterFor(null, shadowColor, size.width).paint(canvas, shadowOffset);
    _painterFor(_stroke(outline), null, size.width).paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(_BackingPainter old) =>
      old.text != text ||
      old.style != style ||
      old.strokeWidth != strokeWidth ||
      old.drop != drop ||
      old.outline != outline ||
      old.shadowColor != shadowColor ||
      old.maxLines != maxLines ||
      old.ellipsis != ellipsis ||
      old.textAlign != textAlign;
}
