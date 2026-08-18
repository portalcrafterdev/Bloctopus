import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/save_data.dart';

/// The three boosters, in the mascot's fiction: his arms do the work.
///
/// Every call site funnels through [onUse] and every button reports its own
/// empty state. That is what [onEarn] now uses: an empty chip stays tappable
/// when a rewarded ad is in hand, and offers one instead of doing nothing.
class BoosterBar extends StatelessWidget {
  final SaveData save;
  final bool canUndo;
  final bool canBlast;
  final bool canReshuffle;
  final bool blastActive;
  final void Function(String boosterId) onUse;
  final VoidCallback onCancelBlast;

  /// Whether an empty chip may offer a rewarded ad.
  ///
  /// False unless one is already loaded. Offering a reward and then failing to
  /// produce the ad reads as the game going back on its word, so the offer is
  /// only made when it can be kept.
  final bool canEarn;

  /// Tapped on an empty chip when [canEarn]. Separate from [onUse] so that
  /// nothing in the game logic path can be reached without a booster in hand.
  final void Function(String boosterId) onEarn;

  const BoosterBar({
    super.key,
    required this.save,
    required this.canUndo,
    required this.canBlast,
    required this.canReshuffle,
    required this.blastActive,
    required this.onUse,
    required this.onCancelBlast,
    this.canEarn = false,
    required this.onEarn,
  });

  @override
  Widget build(BuildContext context) {
    if (blastActive) {
      return _CancelBar(onCancel: onCancelBlast);
    }
    return Row(
      children: [
        Expanded(
          child: _BoosterButton(
            id: BoosterId.undo,
            icon: Icons.undo,
            count: save.boosterCount(BoosterId.undo),
            enabled: canUndo,
            canEarn: canEarn,
            onTap: () => onUse(BoosterId.undo),
            onEarn: () => onEarn(BoosterId.undo),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BoosterButton(
            id: BoosterId.hammer,
            icon: Icons.water_drop_outlined,
            count: save.boosterCount(BoosterId.hammer),
            enabled: canBlast,
            canEarn: canEarn,
            onTap: () => onUse(BoosterId.hammer),
            onEarn: () => onEarn(BoosterId.hammer),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BoosterButton(
            id: BoosterId.refresh,
            icon: Icons.refresh,
            count: save.boosterCount(BoosterId.refresh),
            enabled: canReshuffle,
            canEarn: canEarn,
            onTap: () => onUse(BoosterId.refresh),
            onEarn: () => onEarn(BoosterId.refresh),
          ),
        ),
      ],
    );
  }
}

class _BoosterButton extends StatelessWidget {
  final String id;
  final IconData icon;
  final int count;
  final bool enabled;
  final bool canEarn;
  final VoidCallback onTap;
  final VoidCallback onEarn;

  const _BoosterButton({
    required this.id,
    required this.icon,
    required this.count,
    required this.enabled,
    required this.canEarn,
    required this.onTap,
    required this.onEarn,
  });

  @override
  Widget build(BuildContext context) {
    final out = count <= 0;
    // An empty chip is a live control again when an ad can refill it. Only
    // when it is genuinely empty, though: a chip disabled for a board reason -
    // nothing to undo, a tray already fresh - is not something an ad can fix,
    // and offering one there would be a lie about what the player is buying.
    final offering = out && canEarn;
    // The chip keeps its dark panel whether or not it is usable, and only its
    // contents fade. Fading the whole chip washes it out against the light
    // background, which reads as a different kind of control rather than as
    // the same control unavailable.
    final contentAlpha = enabled || offering ? 1.0 : 0.42;
    return GestureDetector(
      onTap: enabled
          ? onTap
          : offering
          ? onEarn
          : null,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: boardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: chipBorder),
        ),
        child: Opacity(
          opacity: contentAlpha,
          child: Stack(
            children: [
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: textLilac),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        BoosterId.label(id),
                        style: T.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 4,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: offering
                        ? textAccent
                        : (out ? cellEmpty : inkPurple),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // A play mark rather than the zero, so the offer reads as
                  // something to do rather than as the reason the chip is
                  // dead. The count is zero either way; only one of those is
                  // worth a tap.
                  child: offering
                      ? const Icon(
                          Icons.play_arrow_rounded,
                          size: 13,
                          color: bg,
                        )
                      : Text(
                          '$count',
                          style: T.label.copyWith(
                            fontSize: 11,
                            color: out ? textDim : textPrimary,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelBar extends StatelessWidget {
  final VoidCallback onCancel;

  const _CancelBar({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCancel,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: boardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: inkPink.withValues(alpha: 0.6)),
        ),
        child: const Text('Tap a block to blast it, or cancel', style: T.label),
      ),
    );
  }
}
