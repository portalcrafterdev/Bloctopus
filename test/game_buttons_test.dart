import 'package:blocktopus/games/games_ids.dart';
import 'package:blocktopus/games/games_service.dart';
import 'package:blocktopus/widgets/game_sign_in_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The home screen's Play Games block.
///
/// The point of these is the signed in state: achievements had no way in at
/// all before, so twenty of them unlocked in silence.
void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 320, child: GameSignInButton())),
        ),
      ),
    );
    await tester.pump();
  }

  tearDown(() => GamesService.instance.player.value = null);

  testWidgets('signed out it offers only sign in', (tester) async {
    GamesService.instance.player.value = null;
    await pump(tester);

    expect(find.text('Sign in with ${GamesIds.serviceName}'), findsOneWidget);
    expect(find.text('Achievements'), findsNothing);
    expect(find.text('Leaderboards'), findsNothing);
  });

  testWidgets('signed in it names the player and both destinations', (
    tester,
  ) async {
    GamesService.instance.player.value = const GamesPlayer(name: 'Reef');
    await pump(tester);

    expect(find.text('Reef'), findsOneWidget);
    // The sign in prompt is gone: there is nothing left to sign in to.
    expect(find.text('Sign in with ${GamesIds.serviceName}'), findsNothing);

    // Both only when the ids exist. They do on Android and do not on iOS, and
    // the test runs on the host, so this asserts the rule rather than the
    // platform: a destination is offered exactly when it can open.
    expect(
      find.text('Achievements'),
      GamesIds.achievementsAvailable ? findsOneWidget : findsNothing,
    );
    expect(
      find.text('Leaderboards'),
      GamesIds.leaderboardAvailable ? findsOneWidget : findsNothing,
    );
  });

  testWidgets('the destinations are separate tap targets', (tester) async {
    GamesService.instance.player.value = const GamesPlayer(name: 'Reef');
    await pump(tester);

    if (!GamesIds.achievementsAvailable || !GamesIds.leaderboardAvailable) {
      return;
    }
    final achievements = tester.getRect(find.text('Achievements'));
    final leaderboards = tester.getRect(find.text('Leaderboards'));
    expect(
      achievements.overlaps(leaderboards),
      isFalse,
      reason: 'the two keys must not sit on top of each other',
    );
  });

  testWidgets('the block does not overflow a narrow phone', (tester) async {
    GamesService.instance.player.value = const GamesPlayer(
      name: 'A player with a very long display name indeed',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 280, child: GameSignInButton())),
        ),
      ),
    );
    await tester.pump();
    // A RenderFlex overflow throws into the test binding, so reaching here
    // with no exception is the assertion.
    expect(tester.takeException(), isNull);
  });
}
