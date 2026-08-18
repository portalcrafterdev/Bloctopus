import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import '../models/save_data.dart';

/// Sound keys, section 11.1.
class Sfx {
  static const String pickup = 'pickup';
  static const String place = 'place';
  static const String invalid = 'invalid';
  static const String combo = 'combo';
  static const String booster = 'booster';
  static const String ink = 'ink';
  static const String star = 'star';
  static const String levelWin = 'level_win';
  static const String levelFail = 'level_fail';
  static const String blub = 'blub';
  static const String tap = 'tap';

  /// `clear_1` .. `clear_8`, the same sample pitched up a semitone each step.
  static String clear(int step) => 'clear_${step.clamp(1, 8)}';
}

class Music {
  static const String menu = 'music_menu';
  static const String game = 'music_game';
}

/// A preloaded pool of players. Never construct a player per sound.
///
/// Every play is guarded: the audio assets are sourced separately (CC0 or
/// commissioned, never extracted from a reference game) and the game has to
/// run correctly before they land.
class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  /// One player per sound, loaded once, rather than a round robin pool.
  ///
  /// The pool set the source again on every play, and `setSource` is the one
  /// expensive call in the chain: it resolves the asset, copies it out of the
  /// bundle on first use, stats that copy, hands the path to the platform and
  /// then waits for a `prepared` event to come back. Paying that per placement
  /// put the sound audibly behind the block. Loading each source once up
  /// front leaves `stop`, `setVolume` and `resume`, which are all cheap
  /// native calls.
  ///
  /// A round robin also truncated sounds. A three line clear that collects a
  /// star fires six effects inside 210ms, which wrapped the six player pool
  /// and stopped the oldest sound to reuse its player. A player per sound
  /// cannot collide with a different sound at all.
  ///
  /// Keyed on the futures rather than the players, so that a sound played
  /// before its warm up finishes waits for that same load instead of starting
  /// a second one.
  final Map<String, Future<AudioPlayer?>> _players =
      <String, Future<AudioPlayer?>>{};

  /// What each player's volume was last set to, so an unchanged level costs
  /// nothing. Most sounds always play at the same level.
  final Map<String, double> _volumes = <String, double>{};

  /// False when there is no audio backend, which is the case under
  /// `flutter test`.
  bool _hasBackend = false;

  /// Effects ask for no audio focus at all.
  ///
  /// audioplayers requests `AUDIOFOCUS_GAIN` by default, which is a claim to
  /// be the only thing the user is listening to. Android grants it by telling
  /// the previous holder its focus is gone for good, and audioplayers answers
  /// a non transient loss by pausing that player. The previous holder is our
  /// own music, so the first tap on a button, the first block placed, paused
  /// the music for the rest of the session.
  ///
  /// That is what made the music slider and the music toggle look broken:
  /// both worked, there was simply nothing left playing for them to act on,
  /// and turning the toggle back on restarted a track that the very next
  /// effect paused again.
  ///
  /// Effects are short and belong on top of the music, so they claim nothing.
  /// The music player keeps the default gain, so the game still takes focus
  /// once, when the music itself starts.
  static final AudioContext _sfxContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  /// Every sound that gets its own preloaded player, section 11.1.
  static final List<String> _sfxKeys = <String>[
    Sfx.pickup,
    Sfx.place,
    Sfx.invalid,
    Sfx.combo,
    Sfx.booster,
    Sfx.ink,
    Sfx.star,
    Sfx.levelWin,
    Sfx.levelFail,
    Sfx.blub,
    Sfx.tap,
    for (var i = 1; i <= 8; i++) Sfx.clear(i),
  ];

  /// A sound missing from [_sfxKeys] still plays: it loads on first use like
  /// any other. What it loses is the warm up, so the first time it is heard it
  /// pays the full load in the middle of play, which for the pitch ladder is
  /// exactly the wrong moment. A test walks the shipped files against this
  /// list so a new sound cannot quietly miss it.
  @visibleForTesting
  static List<String> get preloadedKeys => List<String>.unmodifiable(_sfxKeys);

  AudioPlayer? _music;

  /// What is actually playing right now, and what the app last asked for.
  ///
  /// These are separate on purpose. Turning music off has to stop the player
  /// without forgetting which track belongs on this screen, otherwise turning
  /// it back on leaves the game silent until the player happens to navigate
  /// somewhere that asks for a track again.
  String? _currentMusic;
  String? _desiredMusic;

  /// Consecutive failures per sound, not a permanent blacklist.
  ///
  /// This used to be a `Set` that a single caught exception added to forever,
  /// which made any transient hiccup - the backend busy, a player still
  /// tearing down a previous clip, focus briefly denied - silence that sound
  /// for the rest of the session with no way back but restarting the app.
  /// A genuinely absent asset still fails every attempt and gets given up on
  /// after [_giveUpAfter] cheap tries; anything that recovers, recovers.
  final Map<String, int> _failures = <String, int>{};
  static const int _giveUpAfter = 3;

  GameSettings _settings = GameSettings();
  bool _ready = false;

  /// Guards against two music requests overlapping: the later one wins, and
  /// the earlier one must not write its result over it.
  int _musicToken = 0;

  bool _givenUpOn(String key) => (_failures[key] ?? 0) >= _giveUpAfter;

  void _noteFailure(String key) => _failures[key] = (_failures[key] ?? 0) + 1;

  void _noteSuccess(String key) => _failures.remove(key);

  /// What the app last asked of the music, whether or not there was a backend
  /// to carry it out.
  ///
  /// Under `flutter test` there is no player to observe, so intent is the only
  /// thing a test can assert on. It is enough for the question that matters:
  /// whether a screen remembered to ask.
  @visibleForTesting
  String musicIntent = 'none';

  @visibleForTesting
  int failureCountFor(String key) => _failures[key] ?? 0;

  @visibleForTesting
  bool isSilencedForTesting(String key) => _givenUpOn(key);

  @visibleForTesting
  void debugFailTimes(String key, int times) {
    for (var i = 0; i < times; i++) {
      _noteFailure(key);
    }
  }

  /// Resets everything a test could have left behind. The service is a
  /// singleton, so without this one test's state leaks into the next.
  @visibleForTesting
  void debugReset() {
    _failures.clear();
    _volumes.clear();
    _currentMusic = null;
    _desiredMusic = null;
    _musicToken = 0;
    musicIntent = 'none';
    _duckTimer?.cancel();
    _duckTimer = null;
    _ducked = false;
    _settings = GameSettings();
  }

  /// Music ducks to 40% while any SFX is playing.
  static const double _duckedVolume = 0.4;
  static const Duration _duckWindow = Duration(milliseconds: 280);
  bool _ducked = false;
  Timer? _duckTimer;

  /// The player's music slider is the ceiling for everything music related.
  double get _musicVolume => _settings.musicVolume;

  /// The shipped audio is generated by `tool/generate_audio.dart` as WAV,
  /// because encoding OGG or M4A needs a codec pure Dart does not have. When
  /// commissioned audio lands, drop OGG/M4A files with the same names into
  /// `assets/audio` and restore the per-platform extension:
  ///
  ///     !kIsWeb && Platform.isIOS ? 'm4a' : 'ogg'
  ///
  /// Both platforms decode WAV natively, so nothing else has to change.
  String get _ext => 'wav';

  Future<void> init(GameSettings settings) async {
    _settings = settings;
    if (_ready) return;
    _ready = true;
    // Probe with one player before committing to the rest. An AudioPlayer
    // registers an event channel on construction, and with no plugin behind it
    // that channel throws asynchronously, outside any try/catch here. Under
    // `flutter test` this costs one stray channel instead of nineteen.
    if (await _playerFor(_sfxKeys.first) == null) return;
    _hasBackend = true;
    unawaited(_warmUp());
  }

  /// Loads the remaining sounds one at a time, in the background.
  ///
  /// Both halves of that matter. Loading all nineteen at once was the first
  /// attempt and it silently lost eight of them: `setSource` waits on a
  /// `prepared` event from the platform, and firing nineteen of those
  /// concurrently is more than the backend reliably answers. On the device
  /// exactly eleven samples reached SoundPool and the pitch ladder never made
  /// a sound. Serially, nothing competes. In the background, nothing waits:
  /// the splash screen carries on and a sound played before its turn comes up
  /// simply loads then, through the same future.
  Future<void> _warmUp() async {
    for (final key in _sfxKeys) {
      await _playerFor(key);
    }
  }

  /// The player for [key], loading it on first use.
  ///
  /// [ReleaseMode.stop] is what makes the load stick: `release` would free the
  /// source after every play and hand the expensive work straight back to the
  /// next one.
  Future<AudioPlayer?> _playerFor(String key) =>
      _players.putIfAbsent(key, () => _create(key));

  Future<AudioPlayer?> _create(String key) async {
    try {
      final p = AudioPlayer(playerId: 'sfx_$key');
      // Before the source is set: on Android the context decides which
      // SoundPool the sample is loaded into.
      await p.setAudioContext(_sfxContext);
      await p.setReleaseMode(ReleaseMode.stop);
      // SoundPool on Android, which is built for exactly this: short effects,
      // decoded once and fired with a native call. A no-op on iOS, where
      // there is only one player mode.
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setSource(AssetSource('audio/$key.$_ext'));
      return p;
    } catch (_) {
      // Dropped rather than remembered as a failure, so the next attempt to
      // play this sound loads it again. A sound that cannot be loaded must
      // degrade to being late, never to being silent for the whole session.
      // The removed future is the one running right now, and it completes with
      // null a line below; ignoring it says so rather than awaiting itself.
      _players.remove(key)?.ignore();
      return null;
    }
  }

  void updateSettings(GameSettings settings) {
    _settings = settings;
    // Touching a sound control is the clearest possible statement that the
    // player wants to hear something, so it also clears the give-up counters.
    // Anything that failed earlier gets a fresh chance here rather than
    // staying dead until the app is restarted.
    _failures.clear();

    if (!settings.music) {
      stopMusic();
      return;
    }
    final music = _music;
    // `_currentMusic` is what we believe; `music.state` is what is true. They
    // drift when a loop ends or the backend drops the track underneath us, and
    // believing the wrong one is what leaves the game silent until a restart.
    final playing =
        music != null &&
        (music.state == PlayerState.playing ||
            music.state == PlayerState.paused);
    if (_currentMusic == null || !playing) {
      // Off to on, never started, stranded by a failure, or the track died.
      final want = _desiredMusic;
      if (want != null) {
        _currentMusic = null;
        playMusic(want);
      }
      return;
    }
    // Genuinely playing: move the volume on the live player rather than
    // restarting the track, so dragging the slider does not stutter the loop.
    // Any duck in progress is abandoned rather than fought with, so the
    // slider is what the player hears.
    _duckTimer?.cancel();
    _duckTimer = null;
    _ducked = false;
    unawaited(_setMusicVolume(music, _musicVolume));
  }

  /// Fire and forget by design: nothing in the game can act on the result of
  /// a sound, and returning a Future would only invite call sites to await a
  /// frame on the audio backend.
  void play(String key, {double volume = 1}) => unawaited(_play(key, volume));

  Future<void> _play(String key, double volume) async {
    if (!_settings.sfx || !_hasBackend || _givenUpOn(key)) return;
    // The per-call volume is the sound's place in the mix; the slider is the
    // player's ceiling over the whole mix. They multiply.
    final level = volume * _settings.sfxVolume;
    if (level <= 0) return;
    final player = await _playerFor(key);
    if (player == null) {
      _noteFailure(key);
      return;
    }
    try {
      // Rewind rather than reload. With the source already set this is a
      // pause and a seek to zero, which is also what frees the sound to be
      // fired again from the top.
      await player.stop();
      if (_volumes[key] != level) {
        await player.setVolume(level);
        _volumes[key] = level;
      }
      await player.resume();
      _noteSuccess(key);
      _duck();
    } catch (_) {
      _noteFailure(key);
      // The player's volume is no longer known to be what was last asked for.
      _volumes.remove(key);
    }
  }

  /// The pitch ladder, section 11.2.
  ///
  /// One sound per line with a 70ms stagger, each step one rung higher, so
  /// three lines at once read as a rising arpeggio.
  void playClearLadder(int clearStreak, int lines) =>
      unawaited(_clearLadder(clearStreak, lines));

  Future<void> _clearLadder(int clearStreak, int lines) async {
    if (!_settings.sfx) return;
    for (var i = 0; i < lines; i++) {
      final step = (clearStreak + i).clamp(1, 8);
      play(Sfx.clear(step));
      if (i < lines - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 70));
      }
    }
    if (clearStreak >= 3) play(Sfx.combo, volume: 0.7);
  }

  // There is deliberately no `playStars` here. The result screen sequences the
  // three star sounds itself, in the same loop that reveals each star, because
  // a sound scheduled independently of the animation drifts away from it.

  void playMusic(String key) {
    musicIntent = 'play';
    unawaited(_playMusic(key));
  }

  Future<void> _playMusic(String key) async {
    // Remembered even when nothing can play it, so that enabling music later
    // knows what to start.
    _desiredMusic = key;
    // An AudioPlayer registers an event channel on construction, and that
    // channel throws asynchronously when no plugin is registered - outside any
    // try/catch here. An empty pool means init() found no audio backend, so
    // never construct a player at all in that case.
    if (!_hasBackend) return;
    if (!_settings.music || _givenUpOn(key)) return;
    if (_currentMusic == key) return;

    final token = ++_musicToken;
    try {
      _music ??= AudioPlayer(playerId: 'music');
      await _music!.setReleaseMode(ReleaseMode.loop);
      await _music!.setVolume(_musicVolume);
      await _music!.play(AssetSource('audio/$key.$_ext'));
      if (token != _musicToken) return; // a later request took over
      // Recorded only once the track really started. Setting it up front left
      // the service believing music was playing after a failure, so every
      // later request short circuited and the game stayed silent.
      _currentMusic = key;
      _noteSuccess(key);
    } catch (_) {
      if (token != _musicToken) return;
      _noteFailure(key);
      _currentMusic = null;
    }
  }

  /// Holds the current track where it is. Used by the pause overlay.
  ///
  /// Deliberately not [stopMusic]: stopping forgets the play position, so
  /// resuming would restart the loop from the top every time the player pauses
  /// to think. `_currentMusic` stays set, because a paused track is still the
  /// track that belongs on this screen.
  void pauseMusic() {
    musicIntent = 'pause';
    final music = _music;
    if (music == null || _currentMusic == null) return;
    try {
      unawaited(music.pause());
    } catch (_) {
      // Nothing playing; `resumeMusic` starts from scratch instead.
      _currentMusic = null;
    }
  }

  /// The other half of [pauseMusic]. Falls back to starting the desired track
  /// from the beginning when there is nothing to resume, which is what happens
  /// if the player turned music off and on again while paused.
  void resumeMusic() {
    musicIntent = 'resume';
    if (!_settings.music) return;
    final music = _music;
    if (music == null || _currentMusic == null) {
      final want = _desiredMusic;
      if (want != null) playMusic(want);
      return;
    }
    try {
      unawaited(music.resume());
    } catch (_) {
      _currentMusic = null;
    }
  }

  void stopMusic() {
    musicIntent = 'stop';
    // `_desiredMusic` deliberately survives: it is what the screen wants, and
    // turning music back on has to know what to restart.
    _currentMusic = null;
    _musicToken++;
    // Cleared before the player is touched: there is nothing left to restore
    // the volume of, and a pending duck timer would otherwise outlive the
    // track it belonged to.
    _unduck();
    final music = _music;
    try {
      if (music != null) unawaited(music.stop());
    } catch (_) {
      // Nothing playing.
    }
  }

  /// Moves the live music player's volume, and treats a failure as "the player
  /// is no longer in a state I understand" rather than ignoring it: leaving
  /// `_currentMusic` set after a failed call is what stranded the music with
  /// no way to restart it.
  Future<void> _setMusicVolume(AudioPlayer music, double level) async {
    try {
      await music.setVolume(level);
    } catch (_) {
      _currentMusic = null;
    }
  }

  /// Pulls the music down for [_duckWindow], and holds it there while sounds
  /// keep arriving.
  ///
  /// One volume write per duck rather than one per sound. A three line clear
  /// that collects a star fires six effects inside 210ms, and this used to
  /// write the music volume six times and leave six timers behind, at the one
  /// frame the game is already busiest with particles, shake and combo text.
  /// Now the first sound ducks and each later one only pushes the timer back.
  void _duck() {
    final music = _music;
    if (music == null || _currentMusic == null) return;
    if (!_ducked) {
      _ducked = true;
      unawaited(_setMusicVolume(music, _duckedVolume * _musicVolume));
    }
    _duckTimer?.cancel();
    _duckTimer = Timer(_duckWindow, _unduck);
  }

  void _unduck() {
    _duckTimer?.cancel();
    _duckTimer = null;
    if (!_ducked) return;
    _ducked = false;
    final music = _music;
    if (music == null || _currentMusic == null) return;
    unawaited(_setMusicVolume(music, _musicVolume));
  }

  Future<void> disposeAll() async {
    _unduck();
    for (final pending in _players.values) {
      await (await pending)?.dispose();
    }
    _players.clear();
    _volumes.clear();
    _hasBackend = false;
    await _music?.dispose();
    _music = null;
    _ready = false;
  }
}

/// Section 10.4. Respects the settings toggle.
class Haptics {
  static GameSettings settings = GameSettings();

  static void light() {
    if (settings.haptics) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (settings.haptics) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (settings.haptics) HapticFeedback.heavyImpact();
  }

  static void selection() {
    if (settings.haptics) HapticFeedback.selectionClick();
  }
}
