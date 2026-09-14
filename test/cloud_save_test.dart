import 'package:blocktopus/games/games_service.dart';
import 'package:blocktopus/models/save_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The cloud sync's edges, which the merge tests cannot reach.
///
/// `save_merge_test.dart` covers the rules. This covers the wiring around
/// them: that a merged blob lands on the live [SaveData] every screen is
/// holding, and that nothing touches the network when there is no account.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GamesService.instance.debugReset();
  });
  tearDown(() => GamesService.instance.debugReset());

  test('a sync with nobody signed in does nothing at all', () async {
    // The common case, and the one that must never reach the plugin: every
    // level completion calls this, signed in or not. In a widget test there
    // is no platform behind the channel, so a call that got through would
    // throw rather than fail silently.
    final save = SaveData(currentLevel: 7, levelsCompleted: 6);
    await GamesService.instance.syncSave(save);

    expect(
      save.currentLevel,
      7,
      reason: 'the save was altered while signed out',
    );
    expect(save.levelsCompleted, 6);
  });

  test(
    'applyJson replaces progress on the instance the screens hold',
    () async {
      // The sync merges into the existing SaveData rather than returning a new
      // one, because every screen holds this object and listens to it. If this
      // ever started returning a fresh instance the screens would keep showing
      // the old numbers, with no error anywhere.
      final save = SaveData(currentLevel: 2, levelsCompleted: 1);
      var notified = 0;
      save.addListener(() => notified++);

      await save.applyJson(<String, dynamic>{
        'version': 1,
        'currentLevel': 412,
        'stars': <String, int>{'1': 3, '2': 2},
        'boosters': <String, int>{
          BoosterId.undo: 5,
          BoosterId.hammer: 1,
          BoosterId.refresh: 4,
        },
        'totalScore': 128400,
        'levelsCompleted': 411,
        'unaidedCompletions': 12,
      });

      expect(save.currentLevel, 412);
      expect(save.totalScore, 128400);
      expect(save.levelsCompleted, 411);
      expect(save.unaidedCompletions, 12);
      expect(save.starsFor(1), 3);
      expect(save.boosterCount(BoosterId.undo), 5);
      expect(notified, greaterThan(0), reason: 'the screens were never told');
    },
  );

  test('applying cloud progress leaves this device its own settings', () async {
    // Volume and haptics are a property of the phone. The merge already keeps
    // the local ones; this checks applyJson does not undo that by reassigning
    // the GameSettings object the settings screen is holding.
    final save = SaveData();
    save.settings.music = false;
    save.settings.musicVolume = 0.2;
    final held = save.settings;

    await save.applyJson(<String, dynamic>{
      'version': 1,
      'currentLevel': 50,
      'stars': <String, int>{},
      'boosters': <String, int>{},
      'settings': <String, dynamic>{'music': true},
      'totalScore': 0,
      'levelsCompleted': 0,
      'unaidedCompletions': 0,
    });

    expect(
      save.settings.music,
      isFalse,
      reason: 'the cloud changed the volume',
    );
    expect(save.settings.musicVolume, 0.2);
    expect(identical(save.settings, held), isTrue);
  });

  test('what is applied survives a reload from disk', () async {
    // applyJson writes as well as notifying. Without the write the merged
    // progress would be correct until the app closed and then be gone, which
    // is the same bug the player reported in the first place.
    final save = await SaveData.load();
    await save.applyJson(<String, dynamic>{
      'version': 1,
      'currentLevel': 412,
      'stars': <String, int>{'1': 3},
      'boosters': <String, int>{},
      'totalScore': 128400,
      'levelsCompleted': 411,
      'unaidedCompletions': 0,
    });

    final reloaded = await SaveData.load();
    expect(reloaded.currentLevel, 412);
    expect(reloaded.totalScore, 128400);
    expect(reloaded.starsFor(1), 3);
  });
}
