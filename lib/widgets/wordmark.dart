import 'package:flutter/material.dart';

import '../app/theme.dart';

/// "Blocktopus" with one block colour per letter and a dark edge around it.
///
/// The edge is not decoration: the palette runs from a deep blue to a bright
/// gold, and without it the darker letters would sink into the background
/// while the lighter ones floated. Stroking every letter the same way puts
/// them all on the same plane.
///
/// Painted as two stacked passes, because a [TextStyle] may carry `color` or
/// `foreground`, never both.
class Wordmark extends StatelessWidget {
  final String text;
  final double fontSize;

  const Wordmark({super.key, this.text = 'Blocktopus', this.fontSize = 46});

  TextSpan _spans(TextStyle Function(int index) styleFor) {
    return TextSpan(
      children: <InlineSpan>[
        for (var i = 0; i < text.length; i++)
          TextSpan(text: text[i], style: styleFor(i)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Weight 600 is the heaviest section 3 allows, so the weight the mark
    // needs comes from the stroke rather than from a bolder face.
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      height: 1.05,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text.rich(
            _spans(
              (_) => base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = fontSize * 0.13
                  ..strokeJoin = StrokeJoin.round
                  ..color = scrim,
              ),
            ),
            textAlign: TextAlign.center,
          ),
          Text.rich(
            _spans((i) => base.copyWith(color: paletteColor(i))),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
