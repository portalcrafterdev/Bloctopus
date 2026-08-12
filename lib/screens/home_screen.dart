import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/audio.dart';
import '../models/save_data.dart';
import '../widgets/block_field.dart';
import '../widgets/chunky_button.dart';
import '../widgets/mascot_view.dart';
import '../widgets/wordmark.dart';
import 'game_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

/// The first screen after the splash. Play drops straight into wherever the
/// player left off; Levels opens the map.
class HomeScreen extends StatefulWidget {
  final SaveData save;

  const HomeScreen({super.key, required this.save});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.save.addListener(_onSaveChanged);
    AudioService.instance.playMusic(Music.menu);
  }

  void _onSaveChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.save.removeListener(_onSaveChanged);
    super.dispose();
  }

  /// Play pushes the map *and then* the level, in that order.
  ///
  /// Pushing the level on its own would be simpler and wrong: popping out of a
  /// level would land back here, while the level's own back arrow and the
  /// result sheet's "Map" button both promise the map. Putting the map
  /// underneath costs one silent route and makes those labels true.
  Future<void> _play() async {
    AudioService.instance.play(Sfx.tap, volume: 0.6);
    final navigator = Navigator.of(context);
    final save = widget.save;
    unawaited(
      navigator.push(
        PageRouteBuilder<void>(
          // No transition: this route is scaffolding for the back stack, not
          // a screen the player asked to look at.
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => MapScreen(save: save),
        ),
      ),
    );
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(levelId: save.currentLevel, save: save),
      ),
    );
    // The level has been popped, so the map is on screen now and wants the
    // menu loop back. Nothing else does this for it: the map only restores its
    // own music for levels it opened itself.
    AudioService.instance.playMusic(Music.menu);
  }

  Future<void> _openMap() async {
    AudioService.instance.play(Sfx.tap, volume: 0.6);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MapScreen(save: widget.save)),
    );
    if (!mounted) return;
    AudioService.instance.playMusic(Music.menu);
  }

  void _openSettings() {
    AudioService.instance.play(Sfx.tap, volume: 0.6);
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(save: widget.save),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final save = widget.save;
    final started = save.levelsCompleted > 0;
    final stars = save.stars.values.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: bg,
      body: Container(
        // Deep at the top, lit at the bottom, ending on the scaffold colour.
        // The only screen in the game that runs this way round: the drift of
        // blocks behind the title needs depth above it and the buttons need
        // light under them.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: homeGradient,
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: BlockField()),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _openSettings,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(Icons.tune, color: textOnBg, size: 22),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // The mascot is the largest thing here, so he is what
                        // has to give on a small screen. Measured off the
                        // constraints rather than off `MediaQuery.size`: this
                        // is the width he is actually being handed, and it is
                        // right even when an ancestor has replaced the media
                        // query wholesale.
                        final mascotSize = math.min(
                          128.0,
                          constraints.maxWidth * 0.32,
                        );
                        // Centred when there is room, scrolling when there is
                        // not. A plain centred column overflows at text scale
                        // 1.6 on a 568pt screen, which is exactly where nobody
                        // tests.
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  MascotView(
                                    size: mascotSize,
                                    state: MascotState.idle,
                                  ),
                                  const SizedBox(height: 10),
                                  const Wordmark(),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Block puzzle',
                                    style: T.label.copyWith(
                                      fontSize: 16,
                                      color: textAccent,
                                      letterSpacing: 2.4,
                                    ),
                                  ),
                                  const SizedBox(height: 38),
                                  _menu(save, started),
                                  const SizedBox(height: 16),
                                  if (started)
                                    Text(
                                      '${save.levelsCompleted} levels, '
                                      '$stars stars',
                                      style: T.dimOnBg,
                                    ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(SaveData save, bool started) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChunkyButton(
            // The word changes but the button does not move: a returning
            // player is resuming, a new one is starting.
            label: started ? 'Continue' : 'Play',
            icon: Icons.play_arrow_rounded,
            color: inkPurple,
            onTap: _play,
          ),
          const SizedBox(height: 4),
          Text('Level ${save.currentLevel}', style: T.dimOnBg),
          const SizedBox(height: 10),
          ChunkyButton(
            label: 'Levels',
            icon: Icons.map_rounded,
            // Gold against the purple: the two buttons have to be told apart
            // at a glance, and a second purple key would just be a shadow of
            // the first.
            color: textAccent,
            onTap: _openMap,
          ),
        ],
      ),
    );
  }
}
