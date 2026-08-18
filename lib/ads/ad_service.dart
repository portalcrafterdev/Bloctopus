import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

/// Owns every ad the game shows.
///
/// The whole point of this class is that the game does not know about ads. The
/// board, the solver, the level loader and the audio all stay exactly as they
/// were; screens call [showInterstitial] or [showRewarded] and get a plain
/// answer. Nothing here can throw into a screen, and nothing here blocks: an
/// ad that has not loaded is simply not shown, and play carries on.
///
/// Full screen formats are preloaded, because [InterstitialAd.load] takes a
/// second or two over the network. Asking for one at the moment it is needed
/// would either stall the player on a black screen or, more likely, miss.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  /// Turned off wholesale when the SDK could not start, so every entry point
  /// degrades to "no ad" rather than to an exception.
  bool _ready = false;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;

  /// True while a full screen ad is on top of the app.
  ///
  /// The game screen pauses its music through the lifecycle observer when an
  /// ad covers the app, and this stops two ads ever being requested at once.
  bool _showing = false;

  bool get isShowing => _showing;

  /// Counts failed loads so a device with no fill, or no network, stops being
  /// asked on a loop. Reset by any success.
  int _interstitialFailures = 0;
  int _rewardedFailures = 0;
  static const int _giveUpAfter = 3;

  @visibleForTesting
  bool debugDisabled = false;

  Future<void> init() async {
    if (debugDisabled) return;
    try {
      await MobileAds.instance.initialize();
      _ready = true;
      unawaited(_loadInterstitial());
      unawaited(_loadRewarded());
    } catch (_) {
      // No Play Services, no network at first run, or a misconfigured app id.
      // The game is fully playable without ads, so this is not fatal.
      _ready = false;
    }
  }

  // -- interstitial ---------------------------------------------------------

  Future<void> _loadInterstitial() async {
    if (!_ready || _interstitial != null || _loadingInterstitial) return;
    if (_interstitialFailures >= _giveUpAfter) return;
    _loadingInterstitial = true;
    await InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitialFailures = 0;
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          _interstitialFailures++;
          _interstitial = null;
        },
      ),
    );
  }

  /// Shows the interstitial if one is ready, and returns whether it did.
  ///
  /// Never waits for a load. A player who has just finished a level is on
  /// their way to the next one, and holding them on a spinner to fetch an ad
  /// is worse than skipping it.
  Future<bool> showInterstitial() async {
    if (!_ready || _showing) return false;
    final ad = _interstitial;
    if (ad == null) {
      unawaited(_loadInterstitial());
      return false;
    }
    _interstitial = null;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _showing = false;
        ad.dispose();
        unawaited(_loadInterstitial());
        if (!done.isCompleted) done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _showing = false;
        ad.dispose();
        unawaited(_loadInterstitial());
        if (!done.isCompleted) done.complete(false);
      },
    );
    _showing = true;
    try {
      await ad.show();
    } catch (_) {
      _showing = false;
      if (!done.isCompleted) done.complete(false);
    }
    return done.future;
  }

  // -- rewarded -------------------------------------------------------------

  Future<void> _loadRewarded() async {
    if (!_ready || _rewarded != null || _loadingRewarded) return;
    if (_rewardedFailures >= _giveUpAfter) return;
    _loadingRewarded = true;
    await RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewardedFailures = 0;
          _rewarded = ad;
        },
        onAdFailedToLoad: (error) {
          _loadingRewarded = false;
          _rewardedFailures++;
          _rewarded = null;
        },
      ),
    );
  }

  /// Whether a rewarded ad could be shown right now.
  ///
  /// Screens use this to decide whether to offer the choice at all. Offering
  /// a reward and then failing to deliver it reads as the game cheating, so
  /// the button is only shown when the ad is already in hand.
  bool get rewardedReady => _ready && _rewarded != null && !_showing;

  /// Shows the rewarded ad and returns true only if the player earned it.
  ///
  /// False covers every other path: no ad loaded, the ad failed to show, or
  /// the player closed it early. The caller must grant nothing on false.
  Future<bool> showRewarded() async {
    if (!_ready || _showing) return false;
    final ad = _rewarded;
    if (ad == null) {
      unawaited(_loadRewarded());
      return false;
    }
    _rewarded = null;
    var earned = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _showing = false;
        ad.dispose();
        unawaited(_loadRewarded());
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _showing = false;
        ad.dispose();
        unawaited(_loadRewarded());
        if (!done.isCompleted) done.complete(false);
      },
    );
    _showing = true;
    try {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
    } catch (_) {
      _showing = false;
      if (!done.isCompleted) done.complete(false);
    }
    return done.future;
  }

  /// Gives the next rewarded ad a head start.
  ///
  /// Called when a screen that offers one appears, so that by the time the
  /// player has run a booster down to zero there is usually one waiting.
  void warmRewarded() => unawaited(_loadRewarded());

  @visibleForTesting
  void debugReset() {
    _ready = false;
    _showing = false;
    _interstitial = null;
    _rewarded = null;
    _loadingInterstitial = false;
    _loadingRewarded = false;
    _interstitialFailures = 0;
    _rewardedFailures = 0;
  }
}
