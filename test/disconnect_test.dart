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

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GamesService.instance.debugReset();
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
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 320, child: GameSignInButton())),
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
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 320, child: GameSignInButton())),
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

  testWidgets('confirming disconnects', (tester) async {
    GamesService.instance.player.value = const GamesPlayer(name: 'Reef');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 320, child: GameSignInButton())),
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
