import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'mascot_view.dart';
import 'menu_button.dart';

/// The pause menu, drawn over the board.
///
/// Normal levels have no timer (section 16), so pausing is not about stopping
/// a clock: it is about being able to put the phone down mid level without
/// losing the board, and about having one place to reach settings, a restart
/// and the way out from. What it really has to do is take every pointer, so a
/// stray thumb cannot drag a piece onto the board while the player is away.
class PauseOverlay extends StatelessWidget {
  final int levelId;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onSettings;
  final VoidCallback onQuit;

  const PauseOverlay({
    super.key,
    required this.levelId,
    required this.onResume,
    required this.onRestart,
    required this.onSettings,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Opaque and with a no-op tap: the veil has to swallow pointers rather
      // than let them through to the board underneath, and tapping the
      // backdrop must not resume, because an accidental unpause drops the
      // player straight back into a live board.
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        color: scrim.withValues(alpha: 0.88),
        child: SafeArea(
          child: Center(
            // Scrolls rather than overflows: four buttons plus the mascot are
            // taller than a 320x568 screen once the system font is turned up.
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MascotView(size: 88, state: MascotState.idle),
                  const SizedBox(height: 18),
                  const Text('Paused', style: T.title),
                  const SizedBox(height: 6),
                  Text('Level $levelId', style: T.body),
                  const SizedBox(height: 26),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: MenuButton(
                            label: 'Resume',
                            filled: true,
                            icon: Icons.play_arrow_rounded,
                            onTap: onResume,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: MenuButton(
                            label: 'Restart level',
                            icon: Icons.refresh_rounded,
                            onTap: onRestart,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: MenuButton(
                            label: 'Settings',
                            icon: Icons.tune,
                            onTap: onSettings,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: MenuButton(
                            label: 'Quit to map',
                            icon: Icons.map_outlined,
                            onTap: onQuit,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Honest rather than reassuring: the board is not persisted,
                  // so quitting really does throw this attempt away.
                  const Text(
                    'Leaving now starts this level over',
                    style: T.dim,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
