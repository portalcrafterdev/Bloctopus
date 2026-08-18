import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../app/theme.dart';
import '../game/audio.dart';
import '../game/board_state.dart';
import '../game/game_controller.dart';
import '../game/level_loader.dart';
import '../models/level.dart';
import '../models/save_data.dart';
import '../widgets/blast_hammer.dart';
import '../widgets/board_view.dart';
import '../widgets/booster_bar.dart';
import '../widgets/combo_text.dart';
import '../widgets/goal_banner.dart';
import '../widgets/line_flash.dart';
import '../widgets/mascot_view.dart';
import '../widgets/particle_layer.dart';
import '../widgets/pause_overlay.dart';
import '../widgets/piece_view.dart';
import '../widgets/tray_view.dart';
import 'result_screen.dart';
import 'settings_screen.dart';

class GameScreen extends StatefulWidget {
  final int levelId;
  final SaveData save;

  const GameScreen({super.key, required this.levelId, required this.save});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  GameController? _game;
  Level? _level;
  Object? _loadError;

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _mascotKey = GlobalKey();

  // Drag state.
  int? _dragSlot;
  Offset? _dragGlobal;
  Ghost? _ghost;

  // Juice.
  final ParticleController _particles = ParticleController();
  final ComboTextController _combo = ComboTextController();
  final LineFlashController _flash = LineFlashController();
  late final Ticker _shakeTicker;
  final ValueNotifier<Offset> _shakeOffset = ValueNotifier<Offset>(Offset.zero);
  double _shakeAmp = 0;
  Duration _shakeElapsed = Duration.zero;
  Duration _shakeEnd = Duration.zero;
  final Random _rnd = Random();

  // Mascot.
  MascotState _mascot = MascotState.idle;
  int _mascotToken = 0;

  bool _resultShown = false;
  bool _tutorialShown = false;
  bool _paused = false;

  /// The Ink Blast swing in flight, if any. Non null means the board is
  /// committed to a target and must not accept another.
  _HammerSwing? _hammer;

  @override
  void initState() {
    super.initState();
    _shakeTicker = createTicker(_onShakeTick);
    _particles.reduceMotion = widget.save.settings.reduceMotion;
    Haptics.settings = widget.save.settings;
    _load();
  }

  Future<void> _load() async {
    try {
      final level = await LevelLoader.instance.load(widget.levelId);
      if (!mounted) return;
      final game = GameController(level: level, save: widget.save)
        ..addPlacementListener(_onPlacement);
      setState(() {
        _level = level;
        _game = game;
      });
      game.addListener(_onGameChanged);
      AudioService.instance.playMusic(Music.game);
      _maybeShowTutorial(level);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  void _maybeShowTutorial(Level level) {
    final info = chapterInfo(level.chapter);
    if (!level.isChapterOpener || info.tutorial == null) return;
    if (widget.save.starsFor(level.id) > 0) return;
    setState(() => _tutorialShown = true);
  }

  void _onGameChanged() {
    final g = _game;
    if (g == null) return;
    if (g.status != LevelStatus.playing && !_resultShown) {
      _resultShown = true;
      _mascot = g.status == LevelStatus.won
          ? MascotState.excited
          : MascotState.sad;
      if (g.status == LevelStatus.won) {
        Haptics.heavy();
        AudioService.instance.play(Sfx.levelWin);
      } else {
        AudioService.instance.play(Sfx.levelFail);
      }
      // Let the last clear finish before the sheet slides in.
      Future<void>.delayed(const Duration(milliseconds: 520), _showResult);
    }
    if (mounted) setState(() {});
  }

  // -- juice ----------------------------------------------------------------

  void _onPlacement(PlacementEvent e) {
    final r = e.result;
    final geometry = _boardGeometry();
    final reduce = widget.save.settings.reduceMotion;

    if (r.linesCleared > 0) {
      if (geometry != null) {
        // Light the completed line up in the colour of the piece that closed
        // it, then let it break apart when the flash starts to fade. The
        // board is already empty underneath: this paints over it for a beat
        // so the clear reads as caused by the piece the player just placed.
        //
        // The flash lives inside the board, so its rects are board-local
        // while the particles are positioned in the screen stack.
        final cell = geometry.cell;
        _flash.flash(
          <Rect>[
            for (final idx in r.clearedCells)
              Rect.fromLTWH(
                (idx % kBoardSize) * cell,
                (idx ~/ kBoardSize) * cell,
                cell,
                cell,
              ),
          ],
          paletteColor(e.colorIndex),
          cell,
          onBreak: () {
            for (var i = 0; i < r.clearedCells.length; i++) {
              final idx = r.clearedCells[i];
              final colorIndex = r.clearedColors[i];
              _particles.burstCell(
                geometry.origin +
                    Offset(
                      (idx % kBoardSize + 0.5) * cell,
                      (idx ~/ kBoardSize + 0.5) * cell,
                    ),
                colorIndex >= 0 ? paletteColor(colorIndex) : textLilac,
                cell,
              );
            }
          },
        );
        _combo.showClear(
          geometry.origin + Offset(geometry.cell * 4, geometry.cell * 3.4),
          r.linesCleared,
          r.scoreGained,
        );
        // The ladder now starts at 2 with "Combo". `showStreak` decides what
        // the word is, and shows nothing below the first rung, so the screen
        // does not need its own copy of the threshold.
        _combo.showStreak(
          geometry.origin + Offset(geometry.cell * 4, geometry.cell * 3.4),
          r.streakAfter,
        );
      }

      if (r.linesCleared >= 3) {
        final m = _mascotCentre();
        if (m != null) _particles.inkBubbles(m);
        _shake(14, 280, reduce);
        Haptics.heavy();
      } else if (r.linesCleared == 2) {
        _shake(8, 200, reduce);
        Haptics.medium();
      } else {
        _shake(4, 140, reduce);
        Haptics.medium();
      }

      // Stars leave the board on the clear that took them, so they get their
      // own pop and their own sound on top of the line clear.
      if (r.starsCollected.isNotEmpty && geometry != null) {
        for (final idx in r.starsCollected) {
          _particles.starPop(
            geometry.origin +
                Offset(
                  (idx % kBoardSize + 0.5) * geometry.cell,
                  (idx ~/ kBoardSize + 0.5) * geometry.cell,
                ),
            geometry.cell,
          );
        }
        AudioService.instance.play(Sfx.star, volume: 0.85);
      }

      AudioService.instance.playClearLadder(r.streakAfter, r.linesCleared);
      AudioService.instance.play(Sfx.blub, volume: 0.5);
      _setMascot(
        r.linesCleared >= 2 || r.streakAfter >= 3
            ? MascotState.excited
            : MascotState.happy,
        r.linesCleared >= 2 ? 900 : 500,
      );
    } else {
      if (geometry != null && r.placedCells.isNotEmpty) {
        final idx = r.placedCells.first;
        _particles.puff(
          geometry.origin +
              Offset(
                (idx % kBoardSize + 0.5) * geometry.cell,
                (idx ~/ kBoardSize + 0.5) * geometry.cell,
              ),
          paletteColor(0),
        );
      }
      Haptics.light();
      AudioService.instance.play(Sfx.place);
    }
  }

  void _setMascot(MascotState state, int ms) {
    final token = ++_mascotToken;
    setState(() => _mascot = state);
    Future<void>.delayed(Duration(milliseconds: ms), () {
      if (mounted && token == _mascotToken) {
        // Settle into whatever the board now warrants, not blindly into idle:
        // a reaction that lands on a nearly dead board should leave him
        // worried, not cheerful.
        setState(() => _mascot = _restingMood());
      }
    });
  }

  /// Idle, unless the board is nearly out of moves.
  MascotState _restingMood() {
    final g = _game;
    if (g == null || g.status != LevelStatus.playing) return MascotState.idle;
    return g.validPlacementCount < 3 ? MascotState.worried : MascotState.idle;
  }

  /// Shake is applied to the board container only, never the whole screen:
  /// shaking the HUD makes the score unreadable.
  ///
  /// The amplitude decays 0.86 a frame and the shake is also cut off at the
  /// stated duration. Decay alone would run about twice as long as section
  /// 10.2 asks for.
  void _shake(double amplitude, int durationMs, bool reduceMotion) {
    if (reduceMotion) return;
    _shakeAmp = amplitude;
    _shakeEnd = Duration(
      milliseconds: _shakeElapsed.inMilliseconds + durationMs,
    );
    if (!_shakeTicker.isActive) _shakeTicker.start();
  }

  void _onShakeTick(Duration elapsed) {
    _shakeElapsed = elapsed;
    _shakeAmp *= 0.86;
    if (_shakeAmp < 0.3 || elapsed >= _shakeEnd) {
      _shakeAmp = 0;
      _shakeOffset.value = Offset.zero;
      _shakeTicker.stop();
      return;
    }
    _shakeOffset.value = Offset(
      (_rnd.nextDouble() * 2 - 1) * _shakeAmp,
      (_rnd.nextDouble() * 2 - 1) * _shakeAmp,
    );
  }

  // -- geometry -------------------------------------------------------------

  _BoardGeometry? _boardGeometry() {
    final boardBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (boardBox == null || stackBox == null || !boardBox.hasSize) return null;
    final origin = stackBox.globalToLocal(boardBox.localToGlobal(Offset.zero));
    return _BoardGeometry(origin, boardBox.size.width / kBoardSize);
  }

  Offset? _mascotCentre() {
    final box = _mascotKey.currentContext?.findRenderObject() as RenderBox?;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stackBox == null || !box.hasSize) return null;
    return stackBox.globalToLocal(
      box.localToGlobal(Offset(box.size.width / 2, box.size.height * 0.3)),
    );
  }

  // -- dragging -------------------------------------------------------------

  void _onDragStart(int slot, Offset global) {
    final g = _game;
    // The veil already swallows the pointer, and a test holds it to that. This
    // is the state machine agreeing with the layout rather than relying on it.
    if (_paused) return;
    if (g == null || g.status != LevelStatus.playing || g.blastMode) return;
    if (g.tray[slot] == null) return;
    Haptics.light();
    AudioService.instance.play(Sfx.pickup, volume: 0.8);
    setState(() {
      _dragSlot = slot;
      _dragGlobal = global;
      _mascot = MascotState.watching;
    });
    _updateGhost();
  }

  void _onDragUpdate(Offset global) {
    if (_dragSlot == null) return;
    setState(() => _dragGlobal = global);
    _updateGhost();
  }

  void _updateGhost() {
    final g = _game;
    final slot = _dragSlot;
    final pos = _dragGlobal;
    if (g == null || slot == null || pos == null) return;
    final piece = g.tray[slot];
    final boardBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (piece == null || boardBox == null || !boardBox.hasSize) return;

    final cell = boardBox.size.width / kBoardSize;
    final origin = boardBox.localToGlobal(Offset.zero);
    final shape = piece.shape;

    // The piece sits above the finger by 1.4 cells, centred horizontally.
    final centre = pos - Offset(0, cell * kDragLiftFactor);
    final topLeft = centre - Offset(shape.w * cell / 2, shape.h * cell / 2);
    final rawX = (topLeft.dx - origin.dx) / cell;
    final rawY = (topLeft.dy - origin.dy) / cell;

    final maxX = kBoardSize - shape.w;
    final maxY = kBoardSize - shape.h;
    if (rawX < -1.2 || rawX > maxX + 1.2 || rawY < -1.2 || rawY > maxY + 1.2) {
      if (_ghost != null) setState(() => _ghost = null);
      return;
    }

    final bx = rawX.round().clamp(0, maxX);
    final by = rawY.round().clamp(0, maxY);
    final valid = g.board.canPlace(shape, bx, by);
    final next = Ghost(
      shape: shape,
      colorIndex: piece.colorIndex,
      bx: bx,
      by: by,
      valid: valid,
    );
    if (_ghost?.bx != bx || _ghost?.by != by || _ghost?.valid != valid) {
      setState(() => _ghost = next);
    }
  }

  void _onDragEnd() {
    final g = _game;
    final slot = _dragSlot;
    final ghost = _ghost;
    setState(() {
      _dragSlot = null;
      _dragGlobal = null;
      _ghost = null;
      if (_mascot == MascotState.watching) _mascot = MascotState.idle;
    });
    if (g == null || slot == null) return;
    if (ghost == null || !ghost.valid) {
      if (ghost != null) AudioService.instance.play(Sfx.invalid, volume: 0.6);
      return;
    }
    g.place(slot, ghost.bx, ghost.by);
    _refreshMascotMood();
  }

  void _onDragCancel() {
    setState(() {
      _dragSlot = null;
      _dragGlobal = null;
      _ghost = null;
      if (_mascot == MascotState.watching) _mascot = MascotState.idle;
    });
  }

  void _refreshMascotMood() {
    // A reaction animation owns the mascot until its timer settles it.
    if (_mascot != MascotState.idle && _mascot != MascotState.worried) return;
    final mood = _restingMood();
    if (mood != _mascot) setState(() => _mascot = mood);
  }

  // -- boosters -------------------------------------------------------------

  void _useBooster(String id) {
    final g = _game;
    if (g == null) return;
    switch (id) {
      case BoosterId.undo:
        if (g.undo()) {
          // A swing still in the air belongs to a move that is being taken
          // back. `blastAt` would refuse it anyway, since undo drops blast
          // mode, but leaving the hammer on screen to strike nothing is worse
          // than no animation at all.
          _hammer = null;
          // Drop any flash still in flight: the placement is being taken back,
          // so a line that was mid-clear must not go on to throw particles for
          // a clear that no longer happened.
          _flash.clear();
          _resultShown = false;
          AudioService.instance.play(Sfx.booster);
          Haptics.selection();
        }
      case BoosterId.hammer:
        g.startBlast();
        Haptics.selection();
      case BoosterId.refresh:
        if (g.reshuffle()) {
          AudioService.instance.play(Sfx.booster);
          Haptics.selection();
        }
    }
  }

  /// Tapping a cell in blast mode swings the hammer at it. The block is not
  /// removed here: it comes off the board when the head actually lands, so the
  /// player sees the thing they aimed at get hit.
  void _onCellTap(int index) {
    final g = _game;
    if (g == null || !g.blastMode || _hammer != null) return;
    // The board reports every tap, empty squares and permanent blocked cells
    // included. Swinging at one of those played the whole animation and then
    // broke nothing, because `blastAt` refuses them at impact: the hammer came
    // down and the block just sat there.
    if (!Cell.blastable(g.board.kinds[index])) {
      AudioService.instance.play(Sfx.invalid, volume: 0.5);
      return;
    }
    final geometry = _boardGeometry();
    if (geometry == null || widget.save.settings.reduceMotion) {
      // Reduce motion means no swing. It still has to blast.
      _breakCell(index);
      return;
    }
    Haptics.light();
    setState(() {
      _hammer = _HammerSwing(
        index,
        Rect.fromLTWH(
          geometry.origin.dx + (index % kBoardSize) * geometry.cell,
          geometry.origin.dy + (index ~/ kBoardSize) * geometry.cell,
          geometry.cell,
          geometry.cell,
        ),
      );
    });
  }

  /// Removes the cell and breaks it apart. Called on the hammer's impact
  /// frame, or straight away when there is no hammer to wait for.
  void _breakCell(int index) {
    final g = _game;
    if (g == null) return;
    final geometry = _boardGeometry();
    // Read before blasting: after it, the cell is empty and has no colour.
    final colorIndex = g.board.colors[index];
    if (!g.blastAt(index)) return;
    AudioService.instance.play(Sfx.ink);
    Haptics.medium();
    if (geometry != null) {
      _particles.shatterCell(
        geometry.origin +
            Offset(
              (index % kBoardSize + 0.5) * geometry.cell,
              (index ~/ kBoardSize + 0.5) * geometry.cell,
            ),
        colorIndex >= 0 ? paletteColor(colorIndex) : inkPurpleHi,
        geometry.cell,
      );
    }
  }

  // -- pause ----------------------------------------------------------------

  /// There is no clock to stop (section 16 rules out timers on normal levels),
  /// so pausing is about the board being safe to walk away from: the veil takes
  /// every pointer, an in-flight drag is dropped rather than left hanging, and
  /// the music holds its position instead of playing to an empty room.
  void _pause() {
    final g = _game;
    if (_paused || g == null || g.status != LevelStatus.playing) return;
    if (_dragSlot != null) _onDragCancel();
    if (g.blastMode) g.cancelBlast();
    AudioService.instance.pauseMusic();
    setState(() {
      _hammer = null;
      _paused = true;
    });
  }

  void _resume() {
    if (!_paused) return;
    AudioService.instance.resumeMusic();
    setState(() => _paused = false);
  }

  void _restartFromPause() {
    final g = _game;
    if (g == null) return;
    AudioService.instance.resumeMusic();
    setState(() {
      _paused = false;
      _resultShown = false;
      _hammer = null;
      _mascot = MascotState.idle;
    });
    _flash.clear();
    _particles.clear();
    _combo.clear();
    g.restart();
  }

  Future<void> _settingsFromPause() async {
    // The music is paused while the board is. But settings is where the music
    // volume is set, and a slider that changes nothing you can hear is a
    // slider that looks broken - which is exactly how it was reported. So the
    // track plays for as long as that screen is open.
    AudioService.instance.resumeMusic();
    await _openSettings();
    // Settings can turn music off and back on, which starts the track playing
    // again. Coming back to a paused board that is humming along would undo
    // half of what pausing means, so put it back where it was.
    if (mounted && _paused) AudioService.instance.pauseMusic();
  }

  // -- result ---------------------------------------------------------------

  Future<void> _showResult() async {
    final g = _game;
    if (!mounted || g == null) return;
    final action = await showResultSheet(
      context,
      level: g.level,
      result: g.result,
      save: widget.save,
    );
    if (!mounted) return;
    switch (action) {
      case ResultAction.next:
        final nextId = g.level.id + 1;
        if (nextId > kLevelCount) {
          Navigator.of(context).pop();
        } else {
          // Replaces this route, so there is no result to wait for.
          unawaited(
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => GameScreen(levelId: nextId, save: widget.save),
              ),
            ),
          );
        }
      case ResultAction.retry:
        setState(() {
          _resultShown = false;
          _hammer = null;
          _mascot = MascotState.idle;
        });
        _particles.clear();
        _combo.clear();
        g.restart();
      case ResultAction.map:
      case null:
        if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _game?.removeListener(_onGameChanged);
    _game?.removePlacementListener(_onPlacement);
    _game?.dispose();
    _shakeTicker.dispose();
    _flash.dispose();
    _shakeOffset.dispose();
    _particles.dispose();
    _combo.dispose();
    super.dispose();
  }

  // -- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) return _ErrorScreen(error: _loadError!);
    final g = _game;
    final level = _level;
    if (g == null || level == null) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(
          child: CircularProgressIndicator(color: inkPurpleHi, strokeWidth: 2),
        ),
      );
    }

    final gradient = chapterGradient(level.chapter);

    return PopScope(
      // While paused, the system back gesture resumes rather than leaving the
      // level. Anyone who meant to leave has "Quit to map" right in front of
      // them, and losing a board to a stray edge swipe is not recoverable.
      canPop: !_paused,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _resume();
      },
      child: _scaffold(g, level, gradient),
    );
  }

  Widget _scaffold(GameController g, Level level, List<Color> gradient) {
    return Scaffold(
      backgroundColor: bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
          ),
        ),
        child: SafeArea(
          child: Stack(
            key: _stackKey,
            clipBehavior: Clip.none,
            // Every child is keyed. Without keys Flutter matches them by
            // index, and this list grows and shrinks as the player plays: the
            // hammer, the drag layer, the tutorial and the pause veil all come
            // and go. Any change shifts everything after it, tearing down and
            // rebuilding element state that had no reason to move.
            children: [
              // The mascot sits behind the booster bar, bottom left.
              Positioned(
                key: const ValueKey<String>('mascot'),
                left: 8,
                bottom: 2,
                child: MascotView(
                  key: _mascotKey,
                  size: 64,
                  state: _mascot,
                  lookAt: _mascotLookAt(),
                ),
              ),
              KeyedSubtree(
                key: const ValueKey<String>('content'),
                child: _content(g, level),
              ),
              // The hammer waits at the edge while the player picks a block,
              // then the swing takes over. The two are never on screen at once.
              if (g.blastMode && _hammer == null)
                const Positioned.fill(
                  key: ValueKey<String>('hammer-ready'),
                  child: BlastHammerReady(),
                ),
              if (_hammer != null)
                Positioned.fill(
                  key: const ValueKey<String>('hammer'),
                  child: BlastHammer(
                    // Keyed on the cell, so aiming again builds a fresh swing
                    // rather than reusing the finished one's controller.
                    key: ValueKey<int>(_hammer!.cellIndex),
                    target: _hammer!.rect,
                    onImpact: () => _breakCell(_hammer!.cellIndex),
                    onDone: () {
                      if (mounted) setState(() => _hammer = null);
                    },
                  ),
                ),
              Positioned.fill(
                key: const ValueKey<String>('particles'),
                child: ParticleLayer(controller: _particles),
              ),
              Positioned.fill(
                key: const ValueKey<String>('combo'),
                child: ComboTextLayer(controller: _combo),
              ),
              if (_dragSlot != null)
                KeyedSubtree(
                  key: const ValueKey<String>('drag'),
                  child: _draggedPiece(g),
                ),
              if (_tutorialShown)
                KeyedSubtree(
                  key: const ValueKey<String>('tutorial'),
                  child: _tutorialOverlay(level),
                ),
              // Last, so it covers the tutorial, the drag layer and the juice.
              if (_paused)
                Positioned.fill(
                  key: const ValueKey<String>('pause'),
                  child: PauseOverlay(
                    levelId: level.id,
                    onResume: _resume,
                    onRestart: _restartFromPause,
                    onSettings: _settingsFromPause,
                    onQuit: () => Navigator.of(context).pop(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Offset? _mascotLookAt() {
    if (_dragGlobal == null) return null;
    final box = _mascotKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.globalToLocal(_dragGlobal!);
  }

  Widget _content(GameController g, Level level) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Column(
        children: [
          ScoreHeader(
            levelId: level.id,
            score: g.score,
            streak: g.streak,
            onBack: () => Navigator.of(context).pop(),
            onPause: _pause,
          ),
          const SizedBox(height: 10),
          GoalBanner(
            level: level,
            progress: g.goalProgress,
            movesLeft: g.movesLeft,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: ValueListenableBuilder<Offset>(
                valueListenable: _shakeOffset,
                builder: (context, offset, child) =>
                    Transform.translate(offset: offset, child: child),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: boardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: border),
                    ),
                    // The flash sits inside the shake transform, not out in
                    // the screen stack with the particles. It has to stay
                    // glued to the cells it is standing in for, and a 14px
                    // shake would slide it off them.
                    child: Stack(
                      children: [
                        BoardView(
                          key: _boardKey,
                          board: g.board,
                          ghost: _ghost,
                          blastMode: g.blastMode,
                          onCellTap: g.blastMode ? _onCellTap : null,
                        ),
                        Positioned.fill(
                          child: LineFlashLayer(controller: _flash),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TrayPanel(
            child: TrayView(
              tray: g.tray,
              draggingSlot: _dragSlot,
              enabled: g.status == LevelStatus.playing && !g.blastMode,
              onDragStart: _onDragStart,
              onDragUpdate: _onDragUpdate,
              onDragEnd: _onDragEnd,
              onDragCancel: _onDragCancel,
              unplayableSlots: _unplayableSlots(g),
            ),
          ),
          const SizedBox(height: 10),
          BoosterBar(
            save: widget.save,
            canUndo: g.canUndo,
            canBlast: g.canBlast,
            canReshuffle: g.canReshuffle,
            blastActive: g.blastMode,
            onUse: _useBooster,
            onCancelBlast: g.cancelBlast,
          ),
          const SizedBox(height: 56), // the mascot's strip
        ],
      ),
    );
  }

  Set<int> _unplayableSlots(GameController g) {
    final out = <int>{};
    for (var i = 0; i < g.tray.length; i++) {
      final p = g.tray[i];
      if (p != null && !g.board.hasPlacementFor(p.shape)) out.add(i);
    }
    return out;
  }

  Widget _draggedPiece(GameController g) {
    final slot = _dragSlot!;
    final piece = g.tray[slot];
    final pos = _dragGlobal;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final boardBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (piece == null ||
        pos == null ||
        stackBox == null ||
        boardBox == null ||
        !boardBox.hasSize) {
      return const SizedBox.shrink();
    }
    // Full board cell size, above the finger, horizontally centred on it.
    final cell = boardBox.size.width / kBoardSize;
    final local = stackBox.globalToLocal(pos);
    final shape = piece.shape;
    return Positioned(
      left: local.dx - shape.w * cell / 2,
      top: local.dy - cell * kDragLiftFactor - shape.h * cell / 2,
      child: IgnorePointer(
        child: PieceView(
          shape: shape,
          colorIndex: piece.colorIndex,
          cellSize: cell,
        ),
      ),
    );
  }

  Widget _tutorialOverlay(Level level) {
    final info = chapterInfo(level.chapter);
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _tutorialShown = false),
        child: Container(
          // Darkens the board behind the tutorial. The white copy below needs
          // something dark under it, which the light background is not.
          color: scrim.withValues(alpha: 0.82),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(info.theme, style: T.title),
                const SizedBox(height: 24),
                const MascotView(size: 120, state: MascotState.idle),
                const SizedBox(height: 16),
                MascotBubble(text: info.tutorial!),
                const SizedBox(height: 28),
                const Text('Tap to start', style: T.dim),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(save: widget.save),
      ),
    );
    if (!mounted) return;
    setState(() {
      _particles.reduceMotion = widget.save.settings.reduceMotion;
      Haptics.settings = widget.save.settings;
    });
  }
}

class _BoardGeometry {
  final Offset origin;
  final double cell;

  const _BoardGeometry(this.origin, this.cell);
}

/// A hammer swing that has been aimed but has not landed yet.
class _HammerSwing {
  final int cellIndex;

  /// The cell's rect in the screen stack, captured at the moment of the tap.
  /// Held rather than recomputed so the hammer cannot drift if the board moves
  /// mid swing.
  final Rect rect;

  const _HammerSwing(this.cellIndex, this.rect);
}

class _ErrorScreen extends StatelessWidget {
  final Object error;

  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MascotView(size: 96, state: MascotState.sad),
                const SizedBox(height: 20),
                const Text(
                  'This depth is still being mapped',
                  style: T.headingOnBg,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The levels for this chapter are not in the build yet.',
                  style: T.dimOnBg,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to the map', style: T.labelOnBg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
