import 'package:blocktopus/models/save_data.dart';
import 'package:blocktopus/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('volume settings', () {
    test('default to something audible', () {
      final s = GameSettings();
      expect(s.sfxVolume, GameSettings.defaultSfxVolume);
      expect(s.musicVolume, GameSettings.defaultMusicVolume);
      // The music bed is ambient and ducks to 40% under effects, so a low
      // default is indistinguishable from no music at all.
      expect(s.musicVolume, greaterThanOrEqualTo(0.6));
    });

    test('survive a save and load round trip', () async {
      final save = await SaveData.load();
      save.updateSettings((s) {
        s.sfxVolume = 0.35;
        s.musicVolume = 0.15;
      });
      await save.save();

      final reloaded = await SaveData.load();
      expect(reloaded.settings.sfxVolume, closeTo(0.35, 1e-9));
      expect(reloaded.settings.musicVolume, closeTo(0.15, 1e-9));
    });

    test('a save written before the sliders existed still loads', () {
      // No volume keys at all: the shape of every save already on a device.
      final s = GameSettings.fromJson(<String, dynamic>{
        'sfx': true,
        'music': false,
        'haptics': true,
        'reduceMotion': true,
      });
      expect(s.music, isFalse);
      expect(s.reduceMotion, isTrue);
      expect(s.sfxVolume, GameSettings.defaultSfxVolume);
      expect(s.musicVolume, GameSettings.defaultMusicVolume);
    });

    test('a corrupt or out of range level is clamped, not trusted', () {
      expect(
        GameSettings.fromJson(<String, dynamic>{
          'musicVolume': 4.2,
        }).musicVolume,
        1,
      );
      expect(
        GameSettings.fromJson(<String, dynamic>{'sfxVolume': -3}).sfxVolume,
        0,
      );
      expect(
        GameSettings.fromJson(<String, dynamic>{'sfxVolume': 'loud'}).sfxVolume,
        GameSettings.defaultSfxVolume,
      );
    });

    testWidgets('both sliders are on the settings screen', (tester) async {
      final save = await SaveData.load();
      await tester.pumpWidget(MaterialApp(home: SettingsScreen(save: save)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Effects volume'), findsOneWidget);
      expect(find.text('Music volume'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('dragging a slider changes the level and persists it', (
      tester,
    ) async {
      final save = await SaveData.load();
      await tester.pumpWidget(MaterialApp(home: SettingsScreen(save: save)));
      await tester.pump(const Duration(milliseconds: 100));

      final music = find.byType(Slider).last;
      final before = save.settings.musicVolume;

      // Drag the thumb to the far left: the lowest the bar goes.
      await tester.drag(music, const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 100));

      expect(save.settings.musicVolume, lessThan(before));
      expect(save.settings.musicVolume, 0);

      // And it reached the disk, not just the in-memory object.
      final reloaded = await SaveData.load();
      expect(reloaded.settings.musicVolume, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a slider is disabled while its toggle is off', (tester) async {
      final save = await SaveData.load();
      save.updateSettings((s) => s.music = false);
      await tester.pumpWidget(MaterialApp(home: SettingsScreen(save: save)));
      await tester.pump(const Duration(milliseconds: 100));

      final music = tester.widget<Slider>(find.byType(Slider).last);
      expect(music.onChanged, isNull, reason: 'music is off');

      final sfx = tester.widget<Slider>(find.byType(Slider).first);
      expect(sfx.onChanged, isNotNull, reason: 'effects are still on');
    });

    testWidgets('turning music off and on again leaves it enabled', (
      tester,
    ) async {
      // The service used to forget which track belonged to the screen when it
      // stopped, so switching music back on left the game silent.
      final save = await SaveData.load();
      await tester.pumpWidget(MaterialApp(home: SettingsScreen(save: save)));
      await tester.pump(const Duration(milliseconds: 100));

      final toggle = find.byType(Switch).at(1); // music
      await tester.tap(toggle);
      await tester.pump(const Duration(milliseconds: 100));
      expect(save.settings.music, isFalse);

      await tester.tap(toggle);
      await tester.pump(const Duration(milliseconds: 100));
      expect(save.settings.music, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
