import 'package:blocktopus/ads/ad_quiet_zone.dart';
import 'package:blocktopus/ads/ad_service.dart';
import 'package:blocktopus/game/audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the app does while a full screen ad is on top of it.
///
/// Android never says this is happening: `AdActivity` is translucent and fills
/// the task, so `MainActivity` is paused but not stopped and the engine goes
/// on believing it is on screen. Left alone, the game paints at full speed
/// behind an ad the player cannot see past, and on a low end phone the ad ends
/// up taking seconds to respond to a tap on its own close button - which reads
/// as the app having hung.
void main() {
  setUp(() {
    AdService.instance.debugSetCovering(false);
    AudioService.instance.debugReset();
  });
  tearDown(() => AdService.instance.debugSetCovering(false));

  testWidgets('an ad going up stops the game animating', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdQuietZone(child: _Spinner())),
    );
    final spinner = tester.state<_SpinnerState>(find.byType(_Spinner));

    // Baseline: it is running, which is what makes the rest meaningful.
    await tester.pump(const Duration(milliseconds: 100));
    final beforeAd = spinner.controller.value;
    expect(beforeAd, greaterThan(0));

    AdService.instance.debugSetCovering(true);
    await tester.pump();
    final atAd = spinner.controller.value;
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      spinner.controller.value,
      atAd,
      reason: 'the game kept animating underneath the ad',
    );
  });

  testWidgets('and picks up again once the ad is gone', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdQuietZone(child: _Spinner())),
    );
    final spinner = tester.state<_SpinnerState>(find.byType(_Spinner));
    await tester.pump(const Duration(milliseconds: 100));

    AdService.instance.debugSetCovering(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final atAd = spinner.controller.value;

    AdService.instance.debugSetCovering(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      spinner.controller.value,
      greaterThan(atAd),
      reason: 'the game stayed frozen after the ad closed',
    );
  });

  testWidgets('the music goes quiet under the ad and comes back after', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdQuietZone(child: _Spinner())),
    );
    expect(AudioService.instance.hiddenCount, 0);

    AdService.instance.debugSetCovering(true);
    await tester.pump();

    expect(
      AudioService.instance.hiddenCount,
      1,
      reason: 'our music played on underneath the ad\'s own audio',
    );

    AdService.instance.debugSetCovering(false);
    await tester.pump();
    expect(AudioService.instance.musicIntent, isNot('pause'));
  });

  testWidgets('the game is not rebuilt when an ad covers it', (tester) async {
    // The child is handed to [ValueListenableBuilder] rather than built inside
    // it. If that ever stops being true the ad does not merely pause the game,
    // it throws the board away and builds a new one behind the ad.
    await tester.pumpWidget(
      const MaterialApp(home: AdQuietZone(child: _Spinner())),
    );
    final spinner = tester.state<_SpinnerState>(find.byType(_Spinner));
    expect(spinner.builds, 1);

    AdService.instance.debugSetCovering(true);
    await tester.pump();
    AdService.instance.debugSetCovering(false);
    await tester.pump();

    expect(
      tester.state<_SpinnerState>(find.byType(_Spinner)).builds,
      1,
      reason: 'the subtree was rebuilt, so the game restarted behind the ad',
    );
  });
}

/// Stands in for everything in the game that is always moving - the mascot's
/// clock above all, which repeats forever on every screen and so is what keeps
/// asking for the next frame.
class _Spinner extends StatefulWidget {
  const _Spinner();

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  int builds = 0;

  @override
  void initState() {
    super.initState();
    controller.repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    builds++;
    return const SizedBox.shrink();
  }
}
