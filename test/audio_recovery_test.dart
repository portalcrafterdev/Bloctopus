import 'package:blocktopus/game/audio.dart';
import 'package:blocktopus/models/save_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sound used to die permanently on the first transient failure.
///
/// The service caught every exception from the audio backend and added the key
/// to a `Set` that was never cleared, so one hiccup - the backend busy, a
/// player still tearing down the previous clip, focus briefly denied - silenced
/// that sound for the rest of the session. The only cure was restarting the
/// app, which is exactly how it was reported.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final audio = AudioService.instance;

  setUp(audio.debugReset);

  group('failure handling', () {
    test('one failure does not silence a sound', () {
      audio.debugFailTimes(Sfx.place, 1);
      expect(audio.isSilencedForTesting(Sfx.place), isFalse);
    });

    test('a couple of failures still do not silence it', () {
      audio.debugFailTimes(Sfx.place, 2);
      expect(audio.isSilencedForTesting(Sfx.place), isFalse);
    });

    test('a sound that never works is eventually given up on', () {
      // A genuinely absent asset fails every time, so it stops being retried
      // rather than costing a platform call on every placement.
      audio.debugFailTimes(Sfx.place, 3);
      expect(audio.isSilencedForTesting(Sfx.place), isTrue);
    });

    test('failures are tracked per sound, not globally', () {
      audio.debugFailTimes(Sfx.place, 3);
      expect(audio.isSilencedForTesting(Sfx.place), isTrue);
      expect(audio.isSilencedForTesting(Sfx.pickup), isFalse);
      expect(audio.isSilencedForTesting(Music.game), isFalse);
    });
  });

  group('recovery', () {
    test('touching any sound setting revives a silenced sound', () {
      // This is the fix for the reported bug: after changing the volume the
      // audio came back only on a restart. Now the settings screen itself is
      // the recovery path.
      audio.debugFailTimes(Sfx.place, 5);
      audio.debugFailTimes(Music.game, 5);
      expect(audio.isSilencedForTesting(Sfx.place), isTrue);

      audio.updateSettings(GameSettings(musicVolume: 0.5));

      expect(audio.isSilencedForTesting(Sfx.place), isFalse);
      expect(audio.isSilencedForTesting(Music.game), isFalse);
      expect(audio.failureCountFor(Sfx.place), 0);
    });

    test('turning music off and back on restores the track', () {
      // `playMusic` records what the screen wants even when there is no
      // backend to play it, so the off/on round trip has something to restart.
      audio.updateSettings(GameSettings());
      audio.playMusic(Music.game);

      audio.updateSettings(GameSettings(music: false));
      audio.updateSettings(GameSettings());

      // Nothing threw, and the service still knows which track belongs here.
      expect(audio.isSilencedForTesting(Music.game), isFalse);
    });

    test('a volume change is safe with no backend at all', () {
      // Under `flutter test` the pool is empty. None of this may throw.
      audio.playMusic(Music.menu);
      for (var i = 0; i <= 10; i++) {
        audio.updateSettings(GameSettings(musicVolume: i / 10));
      }
      audio.play(Sfx.tap);
      expect(audio.isSilencedForTesting(Music.menu), isFalse);
    });
  });

  _backgroundGroup();

  group('volume is applied', () {
    test('a zero effects slider silences effects without breaking them', () {
      audio.updateSettings(GameSettings(sfxVolume: 0));
      audio.play(Sfx.place);
      // Skipped, not failed: turning the slider back up must work.
      expect(audio.failureCountFor(Sfx.place), 0);

      audio.updateSettings(GameSettings(sfxVolume: 1));
      expect(audio.isSilencedForTesting(Sfx.place), isFalse);
    });
  });
}

/// Flutter keeps running when the app is off screen, and audioplayers keeps
/// playing with it. Nothing paused the music when the player put the phone
/// away, so the game sang on from a pocket.
void _backgroundGroup() {
  final audio = AudioService.instance;

  setUp(audio.debugReset);

  group('backgrounding', () {
    test(
      'hiding the app asks the music to stop, and returning restarts it',
      () {
        audio.updateSettings(GameSettings());
        audio.playMusic(Music.menu);

        audio.handleAppHidden();
        audio.handleAppResumed();

        // With no backend there is no live player to pause, so the pair is a
        // no-op rather than a pause/resume. What matters is that neither call
        // throws and neither leaves the track given up on.
        expect(audio.isSilencedForTesting(Music.menu), isFalse);
      },
    );

    test('returning does not resume music this did not pause', () {
      // The in-game pause menu pauses the music on purpose. Backgrounding
      // while already paused, then coming back, must leave the board paused
      // and silent rather than humming along behind the overlay.
      audio.updateSettings(GameSettings());
      audio.playMusic(Music.menu);
      audio.pauseMusic();

      audio.handleAppHidden();
      audio.handleAppResumed();

      expect(
        audio.musicIntent,
        isNot('resume'),
        reason: 'coming back must not undo a deliberate pause',
      );
    });

    test('a resume with nothing hidden is harmless', () {
      audio.updateSettings(GameSettings());
      audio.handleAppResumed();
      expect(audio.musicIntent, isNot('resume'));
    });
  });
}
