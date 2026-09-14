import 'dart:convert';

import 'package:blocktopus/games/games_service.dart';
import 'package:blocktopus/models/save_data.dart';
import 'package:blocktopus/widgets/game_sign_in_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Disconnecting the game from the player's account.
///
/// Not a sign out: neither platform lets an app perform one. What this has to
/// be is *durable* - the platform restores the session at the next cold start,
/// so without a remembered opt out the player reconnects on their own and the
/// button looks broken.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Stands in for the account's snapshot. Null means the account has never
  /// held a save, which is what a first sign in looks like.
  ///
  /// Set up for every test in the file, not only the ones that read it: with
  /// no platform behind the channel the real `loadGame` never answers, so a
  /// disconnect would hang on it rather than fail.
  String? cloud;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GamesService.instance.debugReset();
    cloud = null;
    GamesService.instance
      ..debugLoadSnapshot = (() async => cloud)
      ..debugSaveSnapshot = ((data) async => cloud = data);
  });
  tearDown(() => GamesService.instance.debugReset());

  test('disconnecting forgets the player', () async {
    final games = GamesService.instance;
    games.player.value = const GamesPlayer(name: 'Reef diver');

    await games.disconnect();

    expect(games.signedIn, isFalse);
    expect(games.player.value, isNull);
    expect(games.optedOut, isTrue);
  });

  test('the opt out survives a restart', () async {
    // The whole point. `init()` is what subscribes to the platform, and it has
    // to decline to after a disconnect - otherwise the session comes back on
    // the next launch and the player has to disconnect over and over.
    await GamesService.instance.disconnect();
    GamesService.instance.debugReset();

    await GamesService.instance.init();

    expect(
      GamesService.instance.optedOut,
      isTrue,
      reason: 'the disconnect was forgotten between launches',
    );
    expect(GamesService.instance.signedIn, isFalse);
  });

  test('a disconnected game does not sync progress', () async {
    // Disconnect has to stop the cloud save too, not only hide the name.
    // `syncSave` guards on `signedIn`, which disconnect clears - this holds
    // that wiring together.
    await GamesService.instance.disconnect();
    final save = SaveData(currentLevel: 7, levelsCompleted: 6);

    await GamesService.instance.syncSave(save);

    expect(save.currentLevel, 7);
    expect(save.levelsCompleted, 6);
  });

  test('signing in again clears the opt out', () async {
    // Asking to sign in is the undo. Without this the key would be tapped and
    // nothing would happen, because init() would keep declining.
    await GamesService.instance.disconnect();
    expect(GamesService.instance.optedOut, isTrue);

    // Returns false here - there is no platform behind the channel in a test -
    // but the opt out must be cleared before it even tries.
    await GamesService.instance.signIn();

    expect(GamesService.instance.optedOut, isFalse);
  });

  testWidgets('the control is offered only while signed in', (tester) async {
    GamesService.instance.player.value = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: GameSignInButton(save: SaveData()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Disconnect'), findsNothing);

    GamesService.instance.player.value = const GamesPlayer(name: 'Reef');
    await tester.pump();
    expect(find.text('Disconnect'), findsOneWidget);
  });

  testWidgets('it asks before disconnecting, and cancel means cancel', (
    tester,
  ) async {
    GamesService.instance.player.value = const GamesPlayer(name: 'Reef');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: GameSignInButton(save: SaveData()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      GamesService.instance.signedIn,
      isTrue,
      reason: 'cancelling disconnected anyway',
    );
    expect(GamesService.instance.optedOut, isFalse);
  });

  group('progress belongs to the account', () {
    Future<void> tapDisconnect(WidgetTester tester, SaveData save) async {
      GamesService.instance.player.value = const GamesPlayer(name: 'Reef');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 320, child: GameSignInButton(save: save)),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Disconnect'));
      await tester.pumpAndSettle();
    }

    testWidgets('logging out saves to the account, then clears the device', (
      tester,
    ) async {
      final save = SaveData(
        currentLevel: 10,
        levelsCompleted: 9,
        totalScore: 5000,
        unaidedCompletions: 4,
      );
      save.stars[1] = 3;

      await tapDisconnect(tester, save);

      // The account keeps it.
      expect(cloud, isNotNull, reason: 'nothing was pushed before the wipe');
      final pushed = jsonDecode(cloud!) as Map<String, dynamic>;
      expect(pushed['currentLevel'], 10);
      expect(pushed['levelsCompleted'], 9);

      // The device does not.
      expect(save.currentLevel, 1);
      expect(save.levelsCompleted, 0);
      expect(save.totalScore, 0);
      expect(save.unaidedCompletions, 0);
      expect(save.stars, isEmpty);
      expect(save.boosters, SaveData.startingBoosters);
    });

    testWidgets('signing back in hands it straight back', (tester) async {
      final save = SaveData(
        currentLevel: 10,
        levelsCompleted: 9,
        totalScore: 5000,
      );
      save.stars[1] = 3;
      await tapDisconnect(tester, save);
      expect(save.currentLevel, 1);

      // What the home screen does the moment the player notifier fires, which
      // is how progress arrives after a sign in on any device.
      GamesService.instance.player.value = const GamesPlayer(name: 'Reef');
      await GamesService.instance.syncSave(save);

      expect(save.currentLevel, 10, reason: 'the account did not hand it back');
      expect(save.levelsCompleted, 9);
      expect(save.totalScore, 5000);
      expect(save.starsFor(1), 3);
    });

    testWidgets('an unreachable account leaves the device alone', (
      tester,
    ) async {
      // The one case where the progress must survive a disconnect: if the push
      // did not land, the copy on this phone is the only one there is, and
      // clearing it would not be a reset but a deletion.
      GamesService.instance.debugSaveSnapshot = (_) async =>
          throw Exception('offline');
      final save = SaveData(currentLevel: 10, levelsCompleted: 9);

      await tapDisconnect(tester, save);

      expect(
        save.currentLevel,
        10,
        reason: 'wiped the device without a copy in the account',
      );
      expect(save.levelsCompleted, 9);
      // The disconnect itself is local, so it still holds.
      expect(GamesService.instance.optedOut, isTrue);
      expect(GamesService.instance.signedIn, isFalse);
    });
  });

  group('a pull that fails is not an empty account', () {
    setUp(
      () =>
          GamesService.instance.player.value = const GamesPlayer(name: 'Reef'),
    );

    test(
      'a fresh save is never pushed over a snapshot we could not read',
      () async {
        // The exact shape of losing everything: a phone whose data was just
        // cleared, an owner signing in to get their progress back, and a pull
        // that fails for a moment. The plugin reports "no snapshot yet" and "the
        // network is down" identically, so a failed pull used to mean the merge
        // had no cloud side and a level 1 save went up over the real one.
        var pushed = false;
        GamesService.instance
          ..debugLoadSnapshot = (() async => throw Exception('offline'))
          ..debugSaveSnapshot = ((_) async => pushed = true);

        final ok = await GamesService.instance.syncSave(SaveData());

        expect(
          pushed,
          isFalse,
          reason: 'overwrote the account with a new save',
        );
        expect(ok, isFalse);
      },
    );

    test('a save with progress in it still pushes', () async {
      // The guard must be narrow. A player who has actually played has
      // something worth storing, and a first ever push necessarily follows a
      // pull that found nothing.
      String? cloud;
      GamesService.instance
        ..debugLoadSnapshot = (() async => throw Exception('offline'))
        ..debugSaveSnapshot = ((data) async => cloud = data);

      final ok = await GamesService.instance.syncSave(
        SaveData(currentLevel: 10, levelsCompleted: 9),
      );

      expect(ok, isTrue);
      expect(jsonDecode(cloud!)['currentLevel'], 10);
    });

    test('a first push on a genuinely empty account still happens', () async {
      // Pull succeeds and finds nothing - the ordinary first run. Nothing is
      // at risk, so the guard must not fire.
      String? cloud;
      GamesService.instance
        ..debugLoadSnapshot = (() async => null)
        ..debugSaveSnapshot = ((data) async => cloud = data);

      final ok = await GamesService.instance.syncSave(SaveData());

      expect(ok, isTrue);
      expect(cloud, isNotNull);
    });
  });

  test('a reset leaves nothing of the old run behind', () async {
    // Also the settings screen's reset. `unaidedCompletions` was missed here
    // until the logout work needed the same method, which let a reset player
    // keep their run at the achievement a reset most obviously takes back.
    final save = SaveData(
      currentLevel: 10,
      levelsCompleted: 9,
      totalScore: 5000,
      unaidedCompletions: 4,
    );
    save.stars[1] = 3;
    save.boosters[BoosterId.undo] = 99;

    await save.resetProgress();

    expect(save.currentLevel, 1);
    expect(save.levelsCompleted, 0);
    expect(save.totalScore, 0);
    expect(save.unaidedCompletions, 0);
    expect(save.stars, isEmpty);
    expect(save.boosters, SaveData.startingBoosters);
  });

  testWidgets('confirming disconnects', (tester) async {
    GamesService.instance.player.value = const GamesPlayer(name: 'Reef');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: GameSignInButton(save: SaveData()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    // The sheet's own key, not the one on the home screen behind it.
    await tester.tap(find.widgetWithText(TextButton, 'Disconnect'));
    await tester.pumpAndSettle();

    expect(GamesService.instance.signedIn, isFalse);
    expect(GamesService.instance.optedOut, isTrue);
    expect(find.text('Sign in with Play Games'), findsOneWidget);
  });
}
