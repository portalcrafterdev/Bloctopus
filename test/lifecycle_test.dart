import 'package:blocktopus/game/audio.dart';
import 'package:blocktopus/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app had no lifecycle observer at all, so it never learned it had been
/// put away. Flutter keeps running off screen and audioplayers keeps playing,
/// so the music went on singing from a pocket until the app was killed.
///
/// The platform side cannot be exercised here - under `flutter test` there is
/// no audio backend and no live track to pause. What can be exercised, and
/// what was actually missing, is the wiring: that the app is still listening
/// and still tells the audio service.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final audio = AudioService.instance;

  setUp(audio.debugReset);

  testWidgets('the app tells the audio service when it goes off screen', (
    tester,
  ) async {
    await tester.pumpWidget(const BlocktopusApp());
    await tester.pump();
    expect(audio.hiddenCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(
      audio.hiddenCount,
      1,
      reason: 'nothing stops the music unless the app says it is away',
    );
  });

  testWidgets('being hidden counts too, not only being paused', (tester) async {
    // Android and iOS do not agree on which of these arrives, and on newer
    // Flutter `hidden` comes first. Handling only one of the pair would leave
    // the bug alive on whichever platform sends the other.
    await tester.pumpWidget(const BlocktopusApp());
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();

    expect(audio.hiddenCount, 1);
  });

  testWidgets('a passing cover does not cut the music', (tester) async {
    // `inactive` fires for the notification shade, the app switcher and any
    // permission dialog. Pausing for those would stutter the music during
    // ordinary use, so it is deliberately not handled.
    await tester.pumpWidget(const BlocktopusApp());
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(audio.hiddenCount, 0);
  });
}
