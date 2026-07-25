import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/audio.dart';
import '../models/level.dart';
import '../models/save_data.dart';
import '../widgets/block_field.dart';
import '../widgets/mascot_view.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

/// A vertical path descending through the ocean: shallow at the top, abyss at
/// the bottom. Nodes sit on a gentle sine so the path reads as a current
/// rather than as a list.
///
/// The list is a [CustomScrollView] of fixed extent slivers, so only the
/// visible nodes are built and the scroll offset of any level is exact
/// arithmetic. A chapter is 100 nodes; building all 1500 eagerly would cost
/// seconds on a low end device.
const double _nodeSpacing = 96;
const double _bannerHeight = 108;
const double _chapterHeight = _bannerHeight + 100 * _nodeSpacing;

class MapScreen extends StatefulWidget {
  final SaveData save;

  const MapScreen({super.key, required this.save});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ScrollController _scroll = ScrollController();

  /// The mascot falls asleep after 20 seconds idle on the map.
  bool _asleep = false;
  DateTime _lastInteraction = DateTime.now();

  /// A real timer rather than a self rescheduling `Future.delayed` loop, so it
  /// can actually be cancelled when the screen goes away.
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    widget.save.addListener(_onSaveChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScroll());
    AudioService.instance.playMusic(Music.menu);
    _idleTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkIdle(),
    );
  }

  void _onSaveChanged() {
    if (mounted) setState(() {});
  }

  void _checkIdle() {
    if (!mounted) return;
    final idle = DateTime.now().difference(_lastInteraction).inSeconds >= 20;
    if (idle != _asleep) setState(() => _asleep = idle);
  }

  void _wake() {
    _lastInteraction = DateTime.now();
    if (_asleep) setState(() => _asleep = false);
  }

  /// Opens on the player's current level.
  void _restoreScroll() {
    if (!_scroll.hasClients) return;
    final target =
        _offsetForLevel(widget.save.currentLevel) -
        MediaQuery.of(context).size.height * 0.45;
    _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  double _offsetForLevel(int levelId) {
    final chapter = chapterOf(levelId);
    final indexInChapter = (levelId - 1) % 100;
    return (chapter - 1) * _chapterHeight +
        _bannerHeight +
        indexInChapter * _nodeSpacing;
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    widget.save.removeListener(_onSaveChanged);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openLevel(int id) async {
    _wake();
    AudioService.instance.play(Sfx.tap, volume: 0.6);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(levelId: id, save: widget.save),
      ),
    );
    if (!mounted) return;
    AudioService.instance.playMusic(Music.menu);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final save = widget.save;
    return Scaffold(
      backgroundColor: bg,
      body: Container(
        // Shallow at the top, abyss at the bottom.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              chapterGradient(1).first,
              chapterGradient(6).first,
              chapterGradient(10).first,
              chapterGradient(15).first,
            ],
          ),
        ),
        child: Listener(
          onPointerDown: (_) => _wake(),
          onPointerMove: (_) => _wake(),
          child: Stack(
            children: [
              // The same drift the home screen has, so the two screens are
              // recognisably one place. Shallower here: it sits behind a
              // scrolling list rather than behind a title.
              const Positioned.fill(child: BlockField(depth: 0.34)),
              SafeArea(
                child: Column(
                  children: [
                    _header(save),
                    Expanded(
                      child: CustomScrollView(
                        controller: _scroll,
                        slivers: <Widget>[
                          for (var c = 1; c <= kChapterCount; c++) ...<Widget>[
                            SliverToBoxAdapter(child: _banner(chapterInfo(c))),
                            SliverFixedExtentList(
                              itemExtent: _nodeSpacing,
                              delegate: SliverChildBuilderDelegate(
                                childCount: 100,
                                (context, i) => _LevelNode(
                                  levelId: (c - 1) * 100 + i + 1,
                                  indexInChapter: i,
                                  save: save,
                                  asleep: _asleep,
                                  onTap: _openLevel,
                                ),
                              ),
                            ),
                          ],
                          const SliverToBoxAdapter(child: SizedBox(height: 40)),
                        ],
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

  Widget _banner(ChapterInfo info) {
    return SizedBox(
      height: _bannerHeight,
      child: Center(
        // A panel rather than loose text: the banner is the one thing on this
        // screen that is not a node, so it has to read as a different kind of
        // object, not as a very wide node.
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 34),
          // Tight vertically on purpose. The banner sits in a fixed
          // `_bannerHeight` band, so its padding is the headroom the two lines
          // of copy have when the system font is turned up.
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          decoration: BoxDecoration(
            color: boardBg.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: chipBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chapter ${info.number}',
                style: T.label.copyWith(color: textAccent, letterSpacing: 1.6),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              // One line, always. The banner sits in a fixed band, so a theme
              // name that wraps - or a system font large enough to make it
              // wrap - pushes the panel straight through the bottom of it.
              Text(
                info.theme,
                style: T.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(SaveData save) {
    // The map is pushed from home now, so it has somewhere to go back to. It
    // is not always true - the map also sits under a level, launched straight
    // from home's Play - so ask rather than assume.
    final canGoBack = Navigator.of(context).canPop();
    return Padding(
      padding: EdgeInsets.fromLTRB(canGoBack ? 4 : 18, 8, 10, 8),
      // The title takes what is left after the pills, and ellipses rather
      // than pushing the row off a 320pt screen.
      child: Row(
        children: [
          if (canGoBack)
            GestureDetector(
              onTap: () {
                AudioService.instance.play(Sfx.tap, volume: 0.6);
                Navigator.of(context).pop();
              },
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.arrow_back, color: textOnBg, size: 22),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Straight onto the sky, with no panel behind it, so it takes
                // the dark-on-light styles.
                const Text(
                  'Blocktopus',
                  style: T.titleOnBg,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${save.levelsCompleted} levels, '
                  '${save.stars.values.fold<int>(0, (a, b) => a + b)} stars',
                  style: T.dimOnBg,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          for (final id in BoosterId.all)
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: _BoosterPill(id: id, count: save.boosterCount(id)),
            ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(save: save),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.tune, color: textOnBg, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoosterPill extends StatelessWidget {
  final String id;
  final int count;

  const _BoosterPill({required this.id, required this.count});

  @override
  Widget build(BuildContext context) {
    final icon = switch (id) {
      BoosterId.undo => Icons.undo,
      BoosterId.hammer => Icons.water_drop_outlined,
      _ => Icons.refresh,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: boardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textLilac),
          const SizedBox(width: 4),
          Text('$count', style: T.label.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Where a node sits sideways within its row. Shared by the node and by the
/// path painter, so the two cannot disagree about where the trail goes.
double _nodeOffset(int indexInChapter, double width) =>
    sin(indexInChapter * 0.7) * (width * 0.2);

/// How far down its row a node's centre sits, as a fraction of the row.
/// The node and its stars are a centred column, so this is not exactly a half.
const double _nodeCentreFraction = 40 / _nodeSpacing;

class _LevelNode extends StatelessWidget {
  final int levelId;
  final int indexInChapter;
  final SaveData save;
  final bool asleep;
  final ValueChanged<int> onTap;

  const _LevelNode({
    required this.levelId,
    required this.indexInChapter,
    required this.save,
    required this.asleep,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = save.isUnlocked(levelId);
    final stars = save.starsFor(levelId);
    final current = levelId == save.currentLevel;
    final boss = levelId % 25 == 0;

    final width = MediaQuery.of(context).size.width;
    final dx = _nodeOffset(indexInChapter, width);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Behind everything: the trail joining this node to its neighbours.
        Positioned.fill(
          child: CustomPaint(
            painter: _TrailPainter(
              indexInChapter: indexInChapter,
              // Lit up to the level the player has reached, faint beyond it,
              // so the map shows how far in they are without a progress bar.
              travelled: levelId <= save.currentLevel,
              nextTravelled: levelId < save.currentLevel,
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(dx, 0),
          child: GestureDetector(
            onTap: unlocked ? () => onTap(levelId) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NodeDisc(
                  levelId: levelId,
                  unlocked: unlocked,
                  current: current,
                  boss: boss,
                ),
                const SizedBox(height: 3),
                if (unlocked)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List<Widget>.generate(
                      3,
                      (i) => Icon(
                        i < stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 13,
                        color: i < stars ? textAccent : chipBorder,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (current)
          Transform.translate(
            offset: Offset(dx + 44, -20),
            child: MascotView(
              size: 52,
              state: asleep ? MascotState.sleeping : MascotState.idle,
            ),
          ),
      ],
    );
  }
}

/// The node itself: a lit face on a darker lip, the same shape the home screen
/// buttons use, so a level reads as something to press.
class _NodeDisc extends StatelessWidget {
  final int levelId;
  final bool unlocked;
  final bool current;
  final bool boss;

  const _NodeDisc({
    required this.levelId,
    required this.unlocked,
    required this.current,
    required this.boss,
  });

  @override
  Widget build(BuildContext context) {
    const lip = 5.0;
    final d = boss ? 62.0 : 54.0;

    // Locked wins over everything: a locked boss is still a locked node, and
    // painting it gold would advertise a door that does not open.
    final Color face;
    if (!unlocked) {
      face = boardBg;
    } else if (boss) {
      face = textAccent;
    } else if (current) {
      face = inkPurpleHi;
    } else {
      face = inkPurple;
    }

    final hsl = HSLColor.fromColor(face);
    Color shift(double by) =>
        hsl.withLightness((hsl.lightness + by).clamp(0.0, 1.0)).toColor();

    return Opacity(
      opacity: unlocked ? 1 : 0.42,
      child: SizedBox(
        width: d,
        height: d + lip,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: shift(-0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: d,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[shift(0.07), face],
                  ),
                  shape: BoxShape.circle,
                  // The current node wears a ring so it is findable in a
                  // column of otherwise identical discs.
                  border: current
                      ? Border.all(color: textPrimary, width: 2)
                      : null,
                ),
                child: Text(
                  '$levelId',
                  style: T.label.copyWith(
                    fontSize: boss ? 17 : 15,
                    fontWeight: FontWeight.w600,
                    color: unlocked ? textPrimary : textDim,
                    shadows: unlocked
                        ? <Shadow>[
                            Shadow(color: shift(-0.3), offset: const Offset(0, 1)),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The trail between nodes.
///
/// Each row paints only its own two halves - up to its top edge and down to
/// its bottom edge - so nothing ever has to draw outside its box. The halves
/// meet exactly on the boundary because both are aimed at the same crossing
/// point, which is what keeps the line unbroken down a lazily built list.
class _TrailPainter extends CustomPainter {
  final int indexInChapter;
  final bool travelled;
  final bool nextTravelled;

  const _TrailPainter({
    required this.indexInChapter,
    required this.travelled,
    required this.nextTravelled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height * _nodeCentreFraction;
    final here = Offset(cx + _nodeOffset(indexInChapter, size.width), cy);

    Paint stroke(bool lit) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = lit
          ? inkPurpleHi.withValues(alpha: 0.45)
          : Colors.white.withValues(alpha: 0.10);

    // Upwards, to the previous node. Skipped on the first of a chapter: a
    // banner sits there, not a node.
    if (indexInChapter > 0) {
      final prev = Offset(
        cx + _nodeOffset(indexInChapter - 1, size.width),
        cy - size.height,
      );
      canvas.drawLine(here, _crossing(here, prev, 0), stroke(travelled));
    }
    if (indexInChapter < 99) {
      final next = Offset(
        cx + _nodeOffset(indexInChapter + 1, size.width),
        cy + size.height,
      );
      canvas.drawLine(
        here,
        _crossing(here, next, size.height),
        stroke(nextTravelled),
      );
    }
  }

  /// Where the line from [a] to [b] crosses the horizontal at [y].
  Offset _crossing(Offset a, Offset b, double y) {
    final t = (y - a.dy) / (b.dy - a.dy);
    return Offset(a.dx + (b.dx - a.dx) * t, y);
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.indexInChapter != indexInChapter ||
      old.travelled != travelled ||
      old.nextTravelled != nextTravelled;
}
