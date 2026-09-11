import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/audio.dart';
import '../games/achievements.dart';
import '../models/level.dart';
import '../models/save_data.dart';
import '../widgets/banner_ad_view.dart';
import '../widgets/block_field.dart';
import '../widgets/chunky_button.dart';
import '../widgets/game_sign_in_button.dart';
import '../widgets/mascot_view.dart';
import '../widgets/wordmark.dart';
import 'game_screen.dart';
import 'map_screen.dart';
import 'ranks_screen.dart';
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

  Future<void> _openRanks() async {
    AudioService.instance.play(Sfx.tap, volume: 0.6);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RanksScreen(save: widget.save),
      ),
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
                                  const SizedBox(height: 22),
                                  _continueCard(save, started),
                                  const SizedBox(height: 11),
                                  _boosters(save),
                                  const SizedBox(height: 10),
                                  _achievementCard(save),
                                  const SizedBox(height: 10),
                                  _destinations(),
                                  const SizedBox(height: 16),
                                  // Under the play keys, not above them. It is
                                  // optional: nothing in the game needs an
                                  // account, and a sign in prompt standing
                                  // between a player and the play button is
                                  // the first thing a one star review mentions.
                                  const GameSignInButton(),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Below the menu and inside the SafeArea, so it never
                  // overlaps the buttons and never sits under the gesture bar.
                  const BannerAdView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Where you are and the one button that takes you there, as one object.
  ///
  /// They used to be a button, a caption and a separate progress line. Read in
  /// that order the button said "Continue" and nothing else, and the number
  /// underneath it looked like a footnote. Together the key can say where it
  /// is going.
  Widget _continueCard(SaveData save, bool started) {
    final chapter = chapterInfo(chapterOf(save.currentLevel));
    final progress = (save.currentLevel - 1) / kLevelCount;
    return _panel(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Chapter ${chapter.number} · ${chapter.theme}',
                  style: T.labelOnBg.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text('${save.currentLevel} / $kLevelCount', style: T.dimOnBg),
            ],
          ),
          const SizedBox(height: 10),
          _bar(progress, sunTop, sunBottom, height: 9),
          const SizedBox(height: 12),
          ChunkyButton.primary(
            // The word changes but the button does not move: a returning
            // player is resuming, a new one is starting.
            label: started
                ? 'Continue · Level ${save.currentLevel}'
                : 'Play',
            icon: Icons.play_arrow_rounded,
            height: 58,
            fontSize: 17,
            onTap: _play,
          ),
        ],
      ),
    );
  }

  /// What the player is carrying. Three counts straight off the save, and the
  /// only reason on this screen to have opened the app rather than closed it.
  Widget _boosters(SaveData save) {
    Widget chip(IconData icon, String name, int count) => Expanded(
      child: _panel(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        height: 58,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: textOnBg),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$count', style: T.headingOnBg.copyWith(fontSize: 16)),
                    Text(name, style: T.dimOnBg.copyWith(fontSize: 9.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        chip(
          Icons.undo_rounded,
          BoosterId.label(BoosterId.undo),
          save.boosterCount(BoosterId.undo),
        ),
        const SizedBox(width: 9),
        chip(
          Icons.water_drop_rounded,
          BoosterId.label(BoosterId.hammer),
          save.boosterCount(BoosterId.hammer),
        ),
        const SizedBox(width: 9),
        chip(
          Icons.refresh_rounded,
          BoosterId.label(BoosterId.refresh),
          save.boosterCount(BoosterId.refresh),
        ),
      ],
    );
  }

  /// The achievement the player is closest to.
  ///
  /// The twenty of them are otherwise invisible in the game: they unlock into
  /// Play Games and nothing here ever mentions them. One row gives them a
  /// home and puts a next goal on the first screen. Absent once every
  /// incremental one is finished, rather than claiming false progress.
  Widget _achievementCard(SaveData save) {
    final near = nearestAchievement(save);
    if (near == null) return const SizedBox.shrink();
    final a = near.achievement;
    final remaining = a.steps - near.value;
    return _panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: textAccent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: keyline, width: 2.5),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 19,
              color: sunInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        a.label,
                        style: T.headingOnBg.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${near.value} / ${a.steps}',
                      style: T.labelOnBg.copyWith(
                        fontSize: 12,
                        color: textAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                _bar(near.value / a.steps, sunTop, sunBottom, height: 7),
                const SizedBox(height: 4),
                Text(
                  remaining == 1 ? '1 to go' : '$remaining to go',
                  style: T.dimOnBg.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The two places that are not "keep playing".
  Widget _destinations() {
    Widget key(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        onTap: () {
          AudioService.instance.play(Sfx.tap, volume: 0.6);
          onTap();
        },
        child: _panel(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: textOnBg),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: T.headingOnBg.copyWith(fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Row(
      children: [
        key(Icons.map_rounded, 'Levels', _openMap),
        const SizedBox(width: 10),
        key(Icons.leaderboard_rounded, 'Ranks', _openRanks),
      ],
    );
  }

  /// Foam on the water: a light translucent panel with a white edge. Every
  /// grouped thing on this screen is one, so they read as one family.
  Widget _panel({
    required Widget child,
    EdgeInsets? padding,
    double? height,
  }) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: panelFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: panelEdge, width: 2),
      ),
      child: child,
    );
  }

  /// A rounded progress bar in a dark well, so it reads on light water.
  Widget _bar(
    double t,
    Color from,
    Color to, {
    required double height,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: wellFill,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: t.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: <Color>[from, to]),
            ),
          ),
        ),
      ),
    );
  }
}
