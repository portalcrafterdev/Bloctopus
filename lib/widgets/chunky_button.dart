import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/audio.dart';

/// The big button: a filled face inside a white keyline, dropping one hard
/// shadow straight down, so it reads as a sticker lying on the water.
///
/// It used to be a lit face sitting on a darker lip, with both tones derived
/// from one colour by shifting HSL lightness. That had a failure mode the
/// keyline does not: a near-white face is a *highly* saturated colour in HSL
/// terms, so shifting its lightness produced a lip of obvious lilac under a
/// face that read as white, and the two halves of one key looked like they
/// came from different buttons. Depth now comes from the offset alone, so
/// nothing is derived from the fill and nothing can come out the wrong hue.
///
/// Pressing it drops the face into its own shadow. That is the whole reason
/// this is stateful, and it is worth the state: without the travel the shape
/// looks three dimensional but feels dead.
class ChunkyButton extends StatefulWidget {
  final String label;
  final IconData? icon;

  /// Drawn in place of [icon] when given, for a mark that is not a glyph.
  final Widget? leading;

  /// Drawn after the label. Sized by the caller, so it stays out of the way
  /// of the label's own layout.
  final Widget? trailing;

  /// The face. Used flat, or as the top of a two stop gradient when
  /// [gradientTo] is given.
  final Color color;

  /// The bottom of the face gradient. The yellow "go" keys use it; everything
  /// else fills flat.
  final Color? gradientTo;

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
    this.gradientTo,
    required this.onTap,
    this.height = 62,
    this.fontSize = 18,
    this.labelColor = textPrimary,
  }) : assert(
         icon != null || leading != null,
         'a chunky button needs something to the left of its label',
       );

  /// The primary action: sunlit yellow with dark ink on it. Continue, Next
  /// level, Resume, Try again - every "go" in the game wears this.
  const ChunkyButton.primary({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.trailing,
    required this.onTap,
    this.height = 62,
    this.fontSize = 18,
  }) : color = sunTop,
       gradientTo = sunBottom,
       labelColor = sunInk,
       assert(
         icon != null || leading != null,
         'a chunky button needs something to the left of its label',
       );

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  /// How far the key drops, and how far its shadow is offset. One number, so
  /// a pressed key lands exactly on its own shadow.
  static const double _drop = 6;

  /// The keyline, thick enough to read as a drawn outline rather than a hairline.
  static const double _keyline = 3;

  bool _down = false;

  void _setDown(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);

    // White copy on a bright face needs an edge to survive: on the yellow key
    // plain white sits at barely 1.6:1 against its own background. Four hard
    // offsets in a dark shade read as an outline and cost nothing.
    //
    // A dark label has the opposite problem and needs no help, so the outline
    // is read off the label rather than passed in: it cannot be set wrong.
    final outlined = widget.labelColor.computeLuminance() > 0.5;
    final labelStyle = T.label.copyWith(
      fontFamily: kDisplayFont,
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w600,
      fontVariations: const <FontVariation>[FontVariation('wght', 600)],
      color: widget.labelColor,
      letterSpacing: 0,
      shadows: outlined
          ? <Shadow>[
              for (final o in const <Offset>[
                Offset(-1.4, 0),
                Offset(1.4, 0),
                Offset(0, -1.4),
                Offset(0, 1.6),
              ])
                Shadow(color: scrim, offset: o),
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
        height: widget.height + _drop,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOut,
          // Pressed, the key sits on its shadow and the shadow disappears.
          // Released, it floats the full drop above it. The outer box never
          // changes height, so nothing around the key moves.
          margin: EdgeInsets.only(
            top: _down ? _drop : 0,
            bottom: _down ? 0 : _drop,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: widget.gradientTo == null ? widget.color : null,
            gradient: widget.gradientTo == null
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[widget.color, widget.gradientTo!],
                  ),
            borderRadius: radius,
            border: Border.all(color: keyline, width: _keyline),
            boxShadow: _down
                ? null
                : const <BoxShadow>[
                    BoxShadow(color: stickerShadow, offset: Offset(0, _drop)),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Same edge as the label: a white glyph on the yellow face has
              // the same problem the white copy does.
              widget.leading ??
                  Icon(
                    widget.icon,
                    size: 24,
                    color: widget.labelColor,
                    shadows: labelStyle.shadows,
                  ),
              const SizedBox(width: 12),
              // Flexible, not bare: the row sizes to its content, so a label
              // at a large system font would otherwise carry the row straight
              // past the edge of the button.
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
    );
  }
}
