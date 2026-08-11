import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/audio.dart';

/// The one button shape used by the home screen, the pause overlay and the
/// result sheet.
///
/// It exists so those three cannot drift apart. The unfilled variant is an
/// *inset* on whatever dark panel it sits on, which is why it is [scrim] and
/// not [bg]: the background is a mid violet, so using it here produced a pale
/// slab carrying near-white text.
class MenuButton extends StatelessWidget {
  final String label;
  final bool filled;
  final IconData? icon;
  final double height;
  final VoidCallback onTap;

  const MenuButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.icon,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final content = Text(
      label,
      style: T.label.copyWith(
        fontSize: 15,
        color: filled ? textPrimary : textLilac,
      ),
      overflow: TextOverflow.ellipsis,
    );
    return GestureDetector(
      onTap: () {
        AudioService.instance.play(Sfx.tap, volume: 0.6);
        onTap();
      },
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: filled ? inkPurple : scrim,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: filled ? inkPurple : chipBorder),
        ),
        child: icon == null
            ? content
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: filled ? textPrimary : textLilac,
                  ),
                  const SizedBox(width: 8),
                  // Flexible, not bare: the row sizes to its content, so a
                  // label at a large system font would otherwise carry the row
                  // straight past the edge of the button.
                  Flexible(child: content),
                ],
              ),
      ),
    );
  }
}
