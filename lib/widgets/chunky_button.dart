import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/audio.dart';

/// The big home screen button: a lit face sitting on a darker lip, so it reads
/// as a physical key rather than a rectangle.
///
/// Pressing it drops the face onto the lip. That is the whole reason this is
/// stateful, and it is worth the state: without the travel the shape looks
/// three dimensional but feels dead.
class ChunkyButton extends StatefulWidget {
  final String label;
  final IconData? icon;

  /// Drawn in place of [icon] when given, for a mark that is not a glyph.
  final Widget? leading;

  /// Drawn after the label. Sized by the caller, so it stays out of the way
  /// of the label's own layout.
  final Widget? trailing;

  /// The mid tone. The lit face and the lip are derived from it, so a caller
  /// picks one colour and cannot get the three out of step.
  final Color color;
  final double height;
  final double fontSize;

  /// The label colour. Also decides whether the label is outlined: see the
  /// note on `edge` in `build`.
  final Color labelColor;
  final VoidCallback onTap;

  const ChunkyButton({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.trailing,
    required this.color,
    required this.onTap,
    this.height = 62,
    this.fontSize = 18,
    this.labelColor = textPrimary,
  }) : assert(
         icon != null || leading != null,
         'a chunky button needs something to the left of its label',
       );

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  static const double _lip = 6;

  bool _down = false;

  void _setDown(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(widget.color);
    Color shift(double by) =>
        hsl.withLightness((hsl.lightness + by).clamp(0.0, 1.0)).toColor();

    final radius = BorderRadius.circular(18);
    // White copy on a bright face needs an edge to survive: on the gold button
    // plain white sits at barely 1.6:1 against its own background. Four hard
    // offsets in a dark shade of the button's own colour read as an outline
    // and cost nothing, which is how this shape is drawn everywhere it works.
    //
    // A dark label has the opposite problem and needs no help, so the outline
    // is read off the label rather than passed in: it cannot be set wrong.
    final outlined = widget.labelColor.computeLuminance() > 0.5;
    final edge = shift(-0.34);
    final labelStyle = T.label.copyWith(
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w600,
      color: widget.labelColor,
      shadows: outlined
          ? <Shadow>[
              for (final o in const <Offset>[
                Offset(-1.4, 0),
                Offset(1.4, 0),
                Offset(0, -1.4),
                Offset(0, 1.6),
              ])
                Shadow(color: edge, offset: o),
            ]
          : null,
    );

    return GestureDetector(
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: () {
        AudioService.instance.play(Sfx.tap, volume: 0.6);
        widget.onTap();
      },
      child: SizedBox(
        height: widget.height + _lip,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: shift(-0.21),
                  borderRadius: radius,
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: _down ? _lip : 0,
              height: widget.height,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // A shallow lift only. `inkPurple` is already light, and a
                    // stronger one washed the top of the face out to near
                    // white, which flattened the very shape the lip creates.
                    colors: <Color>[shift(0.06), widget.color],
                  ),
                  borderRadius: radius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Same edge as the label: a white glyph on the gold face
                    // has the same problem the white copy does.
                    widget.leading ??
                        Icon(
                          widget.icon,
                          size: 24,
                          color: widget.labelColor,
                          shadows: labelStyle.shadows,
                        ),
                    const SizedBox(width: 12),
                    // Flexible, not bare: the row sizes to its content, so a
                    // label at a large system font would otherwise carry the
                    // row straight past the edge of the button.
                    Flexible(
                      child: Text(
                        widget.label,
                        style: labelStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 10),
                      widget.trailing!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
