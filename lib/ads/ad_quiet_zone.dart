import 'package:flutter/material.dart';

import '../game/audio.dart';
import 'ad_service.dart';

/// Holds the game still while a full screen ad is over it.
///
/// Android does not tell the app this is happening. Google's `AdActivity` is
/// translucent and fills the task, so `MainActivity` is paused but never
/// stopped: Flutter stays at [AppLifecycleState.inactive], which is also what
/// a pulled down notification shade looks like and so cannot be acted on by
/// the lifecycle observer. The engine therefore never learns it is off screen
/// and the game keeps running at full speed behind an ad nobody can see past.
///
/// That is not merely wasted work. Nothing in this game ever stops moving on
/// its own - the mascot's clock repeats forever, on every screen - so there is
/// always a ticker asking for the next frame. Measured on a Galaxy A06 with an
/// interstitial up: the game painted on at 60 to 85fps, while the ad's own
/// thread skipped upwards of four hundred frames at a stretch and took six
/// seconds to register a tap on its close button. Two renderers and a video
/// decoder on one low end CPU, and the ad is the one that loses. The player
/// taps the close button, nothing happens, and the app reads as hung.
///
/// [TickerMode] is what fixes it. Every animation in this app is driven by a
/// ticker from a provider mixin, and muting them at the root leaves nothing to
/// schedule a frame, so the engine idles and the ad gets the CPU it needs.
///
/// A muted ticker stops being called but keeps its start time, so when the ad
/// closes each animation resumes at wherever it would have got to rather than
/// where it stopped. That is the right way round for this game: everything
/// muted here either loops or is decoration, and none of it is a transition
/// the player is waiting on - the result sheet is already gone by the time an
/// ad goes up.
class AdQuietZone extends StatefulWidget {
  final Widget child;

  const AdQuietZone({super.key, required this.child});

  @override
  State<AdQuietZone> createState() => _AdQuietZoneState();
}

class _AdQuietZoneState extends State<AdQuietZone> {
  @override
  void initState() {
    super.initState();
    AdService.instance.covering.addListener(_onCoverChanged);
  }

  @override
  void dispose() {
    AdService.instance.covering.removeListener(_onCoverChanged);
    super.dispose();
  }

  /// The music, which the lifecycle observer cannot reach for the same reason.
  /// An ad brings its own audio, and ours playing underneath it is the game
  /// talking over the thing the player is being made to sit through.
  void _onCoverChanged() {
    if (AdService.instance.covering.value) {
      AudioService.instance.handleAppHidden();
    } else {
      AudioService.instance.handleAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AdService.instance.covering,
      // Passed through rather than rebuilt: an ad going up must not tear down
      // and rebuild the game underneath it.
      child: widget.child,
      builder: (context, covered, child) =>
          TickerMode(enabled: !covered, child: child!),
    );
  }
}
