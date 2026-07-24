import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/level.dart';

/// The goal strip above the board: what the level wants, how far along the
/// player is, and how many moves are left.
class GoalBanner extends StatelessWidget {
  final Level level;
  final int progress;
  final int? movesLeft;

  const GoalBanner({
    super.key,
    required this.level,
    required this.progress,
    required this.movesLeft,
  });

  @override
  Widget build(BuildContext context) {
    final target = level.target;
    final fraction = target <= 0 ? 1.0 : (progress / target).clamp(0.0, 1.0);
    final boss = level.isBoss;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: boardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: boss ? textAccent.withValues(alpha: 0.55) : border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (boss) ...[
                const Icon(Icons.auto_awesome, size: 15, color: textAccent),
                const SizedBox(width: 6),
                Text('Boss', style: T.accent.copyWith(fontSize: 13)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  goalText(level),
                  style: T.label.copyWith(color: textLilac),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${progress.clamp(0, target)} / $target',
                style: T.label.copyWith(color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: cellEmpty,
              valueColor: AlwaysStoppedAnimation<Color>(
                boss ? textAccent : inkPurpleHi,
              ),
            ),
          ),
          if (movesLeft != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Moves left', style: T.dim),
                const Spacer(),
                Text(
                  '$movesLeft',
                  style: T.label.copyWith(
                    color: movesLeft! <= 3 ? ghostInvalid : textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Score and level number, above the goal strip.
class ScoreHeader extends StatelessWidget {
  final int levelId;
  final int score;
  final int streak;
  final VoidCallback onBack;
  final VoidCallback onPause;

  const ScoreHeader({
    super.key,
    required this.levelId,
    required this.score,
    required this.streak,
    required this.onBack,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconChip(icon: Icons.arrow_back, onTap: onBack),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The header floats on the sky with no panel behind it.
            Text('Level $levelId', style: T.dimOnBg),
            Text('$score', style: T.scoreOnBg),
          ],
        ),
        const Spacer(),
        if (streak > 1)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text('Streak $streak', style: T.accent),
          ),
        // Pause, not settings. Settings live one level in, inside the pause
        // menu: stepping away mid level is the common need, and changing the
        // haptics is not.
        _IconChip(icon: Icons.pause_rounded, onTap: onPause),
      ],
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconChip({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: boardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: chipBorder),
        ),
        child: Icon(icon, size: 19, color: textLilac),
      ),
    );
  }
}
