import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/audio.dart';
import '../games/games_service.dart';
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
    GamesService.instance.player.addListener(_onPlayerChanged);
    // Covers a session the platform restored on its own before this screen
    // existed, which is the usual case on a phone that has signed in before.
    _onPlayerChanged();
    AudioService.instance.playMusic(Music.menu);
  }

  void _onSaveChanged() {
    _onProgressChanged();
    if (mounted) setState(() {});
  }

  /// Pulls the account's progress down the moment there is an account.
  ///
  /// Listening to the player rather than hanging this off the sign in button
  /// on purpose. Signing in is not the only way a player arrives here signed
  /// in: both platforms restore a previous session at launch without asking,
  /// and a second device installing the game is exactly the case this whole
  /// feature exists for. A hook on the button would miss it.
  void _onPlayerChanged() {
    if (!GamesService.instance.signedIn) return;
    unawaited(_syncThenRank());
  }

  /// In that order, because the rank is a reading of what was just submitted.
  ///
  /// Asking for the position before pushing the score returns the position the
  /// player held before this session, which on a device that has just restored
  /// its progress is the wrong number and looks like a stale one.
  Future<void> _syncThenRank() async {
    await GamesService.instance.syncSave(widget.save);
    await GamesService.instance.refreshRank();
  }

  /// The save changing means a level was finished, which is the only thing
  /// that moves the board. [GamesService.refreshRank] drops a second call
  /// while one is already running, so a burst cannot stack up network calls.
  void _onProgressChanged() {
    if (GamesService.instance.signedIn) {
      unawaited(GamesService.instance.refreshRank());
    }
  }

  @override
  void dispose() {
    widget.save.removeListener(_onSaveChanged);
    GamesService.instance.player.removeListener(_onPlayerChanged);
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
    final stars = save.totalStars;

    return Scaffold(
      backgroundColor: bg,
      body: Container(
        // Lit at the top, deep at the bottom, ending on the scaffold colour:
        // the shallowest water in the game, so the dive starts here.
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
                                  const SizedBox(height: 8),
                                  const Wordmark(),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Block puzzle',
                                    style: T.label.copyWith(
                                      fontSize: 16,
                                      color: textAccent,
                                      letterSpacing: 2.4,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _width(_chapterCard(save)),
                                  const SizedBox(height: 10),
                                  _menu(save, started),
                                  const SizedBox(height: 12),
                                  if (started) _width(_stats(save, stars)),
                                  const SizedBox(height: 14),
                                  // Under the play keys, not above them. It is
                                  // optional: nothing in the game needs an
                                  // account, and a sign in prompt standing
                                  // between a player and the play button is
                                  // the first thing a one star review mentions.
                                  GameSignInButton(save: save),
                                  const SizedBox(height: 14),
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

  /// Everything below the play keys reads straight off the save. Nothing here
  /// needs tracking the game does not already do, and nothing here is
  /// decoration: the screen was mostly empty water, and the things worth
  /// putting in it are the things a player came back to check.
  /// The play keys' own width. Everything added here matches it, so the
  /// screen reads as one stack rather than a column of different-sized cards.
  static const double _maxTileWidth = 300;

  Widget _width(Widget child) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: _maxTileWidth),
    child: child,
  );

  /// Where the player is, and how far in. The button says which level it
  /// resumes; this says what that level is part of, which the number alone
  /// never tells you - level 102 means nothing, Kelp Forest means something.
  ///
  /// Shown on a fresh save too, unlike the stat tiles. Three zeroes are worth
  /// nothing to someone who has not played, but "Chapter 1 · Tide Pools" is
  /// the one thing on this screen that says what they are about to dive into.
  Widget _chapterCard(SaveData save) {
    final chapter = chapterOf(save.currentLevel);
    final info = chapterInfo(chapter);
    final t = (save.currentLevel - 1) / kLevelCount;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Chapter $chapter · ${info.theme}',
                  style: T.label.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${save.currentLevel} / $kLevelCount',
                style: T.dim.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 9),
          // Width forced rather than inherited. A Column hands its children
          // *loose* width constraints, so a track that sized to its own fill
          // would shrink to the width of the fill: two percent progress draws
          // a two percent pill floating in the card with nothing behind it,
          // which reads as a decoration rather than a fault.
          //
          // The infinity and the alignment each fix this on their own - a
          // Container with an alignment already expands to its constraints -
          // so neither one alone will fail `home_tiles_test.dart`. Both are
          // here because the alignment is there to place the fill, not to set
          // the width, and a later edit that moves it would silently take the
          // track with it.
          ClipRRect(
            key: const Key('home-progress'),
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: double.infinity,
              height: 9,
              color: scrim,
              alignment: Alignment.centerLeft,

              // `heightFactor` is not optional here, whatever it looks like.
              // Without it the box takes the track's loose height constraint,
              // a DecoratedBox with no child collapses to nothing, and the
              // fill draws 13 pixels wide and zero tall - an empty track at
              // every level in the game. It looked like a design decision.
              child: FractionallySizedBox(
                widthFactor: t.clamp(0.02, 1),
                heightFactor: 1,
                child: const DecoratedBox(
                  decoration: BoxDecoration(color: textAccent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The three numbers a returning player actually wants. They were one line
  /// of dim text - "46 levels, 92 stars" - which is the same information
  /// wearing no clothes.
  Widget _stats(SaveData save, int stars) {
    // The first three read off the save and are always true. The fourth comes
    // off the account, and appears only when there is genuinely a position to
    // show - see [GamesService.rank], where null is the ordinary state and
    // covers signed out, offline, and "no score on the board yet", which is
    // everyone until their first level lands.
    //
    // Deliberately not a placeholder. A dash or a zero in a row of real
    // numbers reads as a rank of nothing rather than as an absent rank, and
    // the row is better three wide than four wide with one of them lying.
    return ValueListenableBuilder<int?>(
      valueListenable: GamesService.instance.rank,
      builder: (context, rank, _) => Row(
        children: [
          Expanded(child: _tile('${save.levelsCompleted}', 'Cleared')),
          const SizedBox(width: 10),
          Expanded(child: _tile('$stars', 'Stars')),
          const SizedBox(width: 10),
          Expanded(child: _tile(_short(save.totalScore), 'Score')),
          if (rank != null) ...[
            const SizedBox(width: 10),
            Expanded(child: _tile('#${_short(rank)}', 'Rank')),
          ],
        ],
      ),
    );
  }

  Widget _tile(String value, String label) {
    return _panel(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        children: [
          // Shrinks rather than overflows. Three tiles across 300pt left each
          // number 84pt to play with; a fourth cuts that to 67, and "#1204"
          // in a display face does not fit it at 19pt.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: T.heading.copyWith(fontSize: 19)),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: T.dim.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// The game's panel: a dark card on the water, the same shape the goal
  /// banner and the booster bar already use, so the home screen does not
  /// invent a second one.
  Widget _panel({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(14, 11, 14, 13),
      decoration: BoxDecoration(
        color: boardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  /// 128,400 reads as 128k in a tile this size. Full precision below 10,000,
  /// where every digit still fits and still means something.
  static String _short(int n) {
    if (n < 10000) return '$n';
    if (n < 1000000) return '${(n / 1000).floor()}k';
    return '${(n / 100000).floor() / 10}m';
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
            color: inkTeal,
            onTap: _play,
          ),
          const SizedBox(height: 4),
          Text('Level ${save.currentLevel}', style: T.dimOnBg),
          const SizedBox(height: 10),
          ChunkyButton(
            label: 'Levels',
            icon: Icons.map_rounded,
            // Gold against the teal: the two buttons have to be told apart
            // at a glance, and a second teal key would just be a shadow of
            // the first.
            color: textAccent,
            onTap: _openMap,
          ),
        ],
      ),
    );
  }
}
