import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/save_data.dart';

/// The three boosters, in the mascot's fiction: his arms do the work.
///
/// Every call site funnels through [onUse] and every button reports its own
/// empty state, so a "watch an ad to earn one" hook can be added later without
/// touching game logic.
class BoosterBar extends StatelessWidget {
  final SaveData save;
  final bool canUndo;
  final bool canBlast;
  final bool canReshuffle;
  final bool blastActive;
  final void Function(String boosterId) onUse;
  final VoidCallback onCancelBlast;

  const BoosterBar({
    super.key,
    required this.save,
    required this.canUndo,
    required this.canBlast,
    required this.canReshuffle,
    required this.blastActive,
    required this.onUse,
    required this.onCancelBlast,
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
            onTap: () => onUse(BoosterId.undo),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BoosterButton(
            id: BoosterId.hammer,
            icon: Icons.water_drop_outlined,
            count: save.boosterCount(BoosterId.hammer),
            enabled: canBlast,
            onTap: () => onUse(BoosterId.hammer),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BoosterButton(
            id: BoosterId.refresh,
            icon: Icons.refresh,
            count: save.boosterCount(BoosterId.refresh),
            enabled: canReshuffle,
            onTap: () => onUse(BoosterId.refresh),
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
  final VoidCallback onTap;

  const _BoosterButton({
    required this.id,
    required this.icon,
    required this.count,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final out = count <= 0;
    // The chip keeps its dark panel whether or not it is usable, and only its
    // contents fade. Fading the whole chip washes it out against the light
    // background, which reads as a different kind of control rather than as
    // the same control unavailable.
    final contentAlpha = enabled ? 1.0 : 0.42;
    return GestureDetector(
      onTap: enabled ? onTap : null,
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
                    color: out ? cellEmpty : inkPurple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
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
