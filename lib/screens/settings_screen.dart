import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/audio.dart';
import '../models/save_data.dart';

class SettingsScreen extends StatefulWidget {
  final SaveData save;

  const SettingsScreen({super.key, required this.save});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _set(void Function(GameSettings s) change) {
    setState(() {
      widget.save.updateSettings(change);
      Haptics.settings = widget.save.settings;
      AudioService.instance.updateSettings(widget.save.settings);
    });
  }

  /// A slider fires on every frame of a drag, and section 12 says the save
  /// blob is written on settings changes, never per frame. So a drag applies
  /// to the live audio immediately and is persisted once, on release.
  void _drag(void Function(GameSettings s) change) {
    setState(() {
      change(widget.save.settings);
      AudioService.instance.updateSettings(widget.save.settings);
    });
  }

  void _persist({String? preview}) {
    // An empty change: the settings object was already mutated by _drag, this
    // is the notify-and-write half.
    widget.save.updateSettings((_) {});
    if (preview != null) AudioService.instance.play(preview);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.save.settings;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: textOnBg),
                  ),
                  // The back button is a fixed 48pt, so the title has to take
                  // what is left rather than its natural width: at a large
                  // system font it is wider than the row.
                  const Expanded(
                    child: Text(
                      'Settings',
                      style: T.titleOnBg,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Scrolls: four toggles plus the stats panel do not fit on a
              // 568pt screen, and a fixed column would overflow there.
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _Toggle(
                      label: 'Sound effects',
                      value: s.sfx,
                      onChanged: (v) => _set((s) => s.sfx = v),
                    ),
                    _Volume(
                      label: 'Effects volume',
                      value: s.sfxVolume,
                      // Nothing to set the level of while effects are off.
                      enabled: s.sfx,
                      onChanged: (v) => _drag((s) => s.sfxVolume = v),
                      // A sound on release, so the level can be heard while
                      // it is being chosen rather than guessed at.
                      onEnd: () => _persist(preview: Sfx.place),
                    ),
                    _Toggle(
                      label: 'Music',
                      value: s.music,
                      onChanged: (v) => _set((s) => s.music = v),
                    ),
                    _Volume(
                      label: 'Music volume',
                      value: s.musicVolume,
                      enabled: s.music,
                      onChanged: (v) => _drag((s) => s.musicVolume = v),
                      onEnd: _persist,
                    ),
                    _Toggle(
                      label: 'Haptics',
                      value: s.haptics,
                      onChanged: (v) => _set((s) => s.haptics = v),
                    ),
                    _Toggle(
                      label: 'Reduce motion',
                      note: 'Turns off screen shake and halves the particles.',
                      value: s.reduceMotion,
                      onChanged: (v) => _set((s) => s.reduceMotion = v),
                    ),
                    const SizedBox(height: 10),
                    _Stats(save: widget.save),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: _confirmReset,
                        child: const Text('Reset progress', style: T.dimOnBg),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: boardBg,
        title: const Text('Reset progress', style: T.heading),
        content: const Text(
          'This clears every star and returns you to level 1. It cannot be undone.',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it', style: T.label),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Reset', style: T.label.copyWith(color: ghostInvalid)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.save.resetProgress();
      if (mounted) setState(() {});
    }
  }
}

/// A labelled 0..100% bar. Sits directly under the toggle it belongs to, and
/// dims out when that toggle is off rather than disappearing, so the row does
/// not jump around as the switch is flipped.
class _Volume extends StatelessWidget {
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final VoidCallback onEnd;

  const _Volume({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final percent = '${(value * 100).round()}%';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      decoration: BoxDecoration(
        color: boardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: chipBorder),
      ),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: T.label.copyWith(fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(percent, style: T.dim),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: inkPurple,
                inactiveTrackColor: chipBorder,
                thumbColor: enabled ? inkPurpleHi : chipBorder,
                overlayColor: inkPurple.withValues(alpha: 0.18),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                // The bar is the whole control, so it should not be padded in
                // from the edges of the panel it sits in.
                padding: EdgeInsets.zero,
              ),
              child: Slider(
                value: value.clamp(0, 1),
                // 20 steps: fine enough to tune, coarse enough that the same
                // level can be found again.
                divisions: 20,
                label: percent,
                onChanged: enabled ? onChanged : null,
                onChangeEnd: enabled ? (_) => onEnd() : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final String? note;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: boardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: chipBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: T.label.copyWith(fontSize: 15)),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note!, style: T.dim.copyWith(fontSize: 12)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: textPrimary,
            activeTrackColor: inkPurple,
            inactiveTrackColor: cellEmpty,
            inactiveThumbColor: textDim,
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final SaveData save;

  const _Stats({required this.save});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: boardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _stat('Levels', '${save.levelsCompleted}'),
          _stat('Stars', '${save.stars.values.fold<int>(0, (a, b) => a + b)}'),
          _stat('Total score', '${save.totalScore}'),
        ],
      ),
    );
  }

  /// Equal thirds, so a long total score cannot push the row off a narrow
  /// screen.
  Widget _stat(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(value, style: T.heading, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label, style: T.dim, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}
