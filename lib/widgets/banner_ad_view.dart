import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads/ad_ids.dart';
import '../app/theme.dart';

/// An anchored adaptive banner, for the menu screens only.
///
/// Deliberately absent from the game screen. A banner along the bottom there
/// would sit directly under the tray, which is where the finger lifts off at
/// the end of every drag, and a mis-tap on an ad is not just annoying: Google
/// counts accidental clicks as invalid traffic, and the penalty for enough of
/// them is the AdMob account.
///
/// The box keeps its height whether or not an ad ever arrives. A banner that
/// appears late and shoves the menu upwards under the player's thumb is how a
/// tap lands on the wrong thing.
class BannerAdView extends StatefulWidget {
  const BannerAdView({super.key});

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  BannerAd? _ad;
  bool _loaded = false;

  /// Held so a late load that arrives after this widget is gone can be thrown
  /// away rather than attached to a dead element.
  bool _disposed = false;

  /// Failed attempts since the last success.
  ///
  /// A banner request fails for reasons that pass: a moment of bad DNS, a
  /// handover between wifi and mobile, a device that filters ad domains, a
  /// genuine no fill. Without a retry the first of those costs the whole
  /// screen its ad for as long as the player stays on it, which is the rest
  /// of the session for the home screen. Bounded, so a device that will never
  /// serve an ad is asked three times and then left alone rather than being
  /// polled flat.
  int _attempts = 0;
  static const int _maxAttempts = 3;
  Timer? _retry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad == null) _load();
  }

  void _scheduleRetry() {
    if (_disposed || _attempts >= _maxAttempts) return;
    _attempts++;
    _retry?.cancel();
    // Backs off: 2s, then 4s, then 6s. Long enough that a blip has passed,
    // short enough that the ad is there before the player has read the menu.
    _retry = Timer(Duration(seconds: 2 * _attempts), () {
      if (_disposed || !mounted || _ad != null) return;
      _load();
    });
  }

  Future<void> _load() async {
    final width = MediaQuery.sizeOf(context).width.truncate();
    final AdSize? size;
    try {
      size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    } catch (_) {
      // No ads plugin behind the channel, which is every widget test. The
      // reserved space stays empty and the screen is otherwise unchanged.
      return;
    }
    if (size == null || _disposed) return;

    final ad = BannerAd(
      size: size,
      adUnitId: AdIds.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (_disposed) return;
          _attempts = 0;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (_disposed) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
          // The reserved space stays empty in the meantime, so a retry that
          // lands late costs nothing and moves nothing.
          _scheduleRetry();
        },
      ),
    );
    _ad = ad;
    try {
      await ad.load();
    } catch (_) {
      _ad = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    // 50 is the standard banner height, and what the adaptive size falls back
    // to on a phone in portrait. Reserving it up front is what stops the menu
    // moving when the ad lands.
    final height = _loaded && ad != null ? ad.size.height.toDouble() : 50.0;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: _loaded && ad != null
          ? AdWidget(ad: ad)
          : (AdIds.usingTestAds
                ? const _TestAdPlaceholder()
                : const SizedBox.shrink()),
    );
  }
}

/// Only ever visible in debug builds, and only while the banner is empty.
///
/// Its job is to make the reserved space obvious during layout work, so an ad
/// slot is never mistaken for a gap.
class _TestAdPlaceholder extends StatelessWidget {
  const _TestAdPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'ad slot',
        style: T.dimOnBg.copyWith(fontSize: 11, letterSpacing: 0.5),
      ),
    );
  }
}
