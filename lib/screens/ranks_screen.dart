import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../games/games_ids.dart';
import '../games/games_service.dart';
import '../models/save_data.dart';
import '../widgets/chunky_button.dart';

class RanksScreen extends StatelessWidget {
  final SaveData save;

  const RanksScreen({super.key, required this.save});

  Future<void> _openOnlineRanks(BuildContext context) async {
    final opened = await GamesService.instance.showLeaderboard();
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to view online ranks.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stars = save.totalStars;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Ranks'),
        backgroundColor: bg,
        foregroundColor: textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const Text('Your progress', style: T.heading),
          const SizedBox(height: 14),
          _stat('Total score', '${save.totalScore}', Icons.stars_rounded),
          const SizedBox(height: 10),
          _stat(
            'Levels completed',
            '${save.levelsCompleted}',
            Icons.flag_rounded,
          ),
          const SizedBox(height: 10),
          _stat('Stars earned', '$stars', Icons.star_rounded),
          if (GamesIds.leaderboardAvailable) ...[
            const SizedBox(height: 28),
            ChunkyButton.primary(
              label: 'View online ranks',
              icon: Icons.leaderboard_rounded,
              onTap: () => _openOnlineRanks(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: boardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: textAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: T.body)),
          Text(value, style: T.heading.copyWith(color: textAccent)),
        ],
      ),
    );
  }
}