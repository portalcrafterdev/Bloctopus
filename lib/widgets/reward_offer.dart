import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/save_data.dart';
import 'mascot_view.dart';

/// Asks whether the player wants to watch an ad for one booster.
///
/// Returns true only on a deliberate yes. Dismissing the sheet, tapping the
/// scrim or backing out all return null, which the caller treats as no.
///
/// The ask is not optional. An ad that starts because a finger landed on the
/// wrong chip is the fastest route to a one star review, and Google's own
/// rewarded policy requires the choice to be explicit and the reward to be
/// stated up front. So the sheet names the booster it is offering.
Future<bool?> showRewardOffer(
  BuildContext context, {
  required String boosterId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _RewardOffer(boosterId: boosterId),
  );
}

class _RewardOffer extends StatelessWidget {
  final String boosterId;

  const _RewardOffer({required this.boosterId});

  @override
  Widget build(BuildContext context) {
    final label = BoosterId.label(boosterId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      decoration: const BoxDecoration(
        color: boardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotView(size: 74, state: MascotState.idle),
            const SizedBox(height: 14),
            Text('Out of $label', style: T.title),
            const SizedBox(height: 8),
            // Section 9.4: he explains, he does not sell. Plain, short, and it
            // says exactly what the trade is before anything starts.
            const Text(
              'Watch a short video to get one more.',
              style: T.dim,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text('Watch for one ${label.toLowerCase()}'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No thanks', style: T.dim),
            ),
          ],
        ),
      ),
    );
  }
}
