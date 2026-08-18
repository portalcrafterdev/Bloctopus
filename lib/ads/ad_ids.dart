import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Every AdMob identifier the app uses, and the rule for which set is live.
///
/// The rule is the important part. Google's policy is that a publisher must
/// never click, or generate impressions on, their own live ads, and the usual
/// way that happens by accident is a developer testing a debug build against
/// the real unit ids. It is treated as invalid traffic, and the penalty is the
/// AdMob account, not the app. So debug builds serve Google's own test units
/// and release builds serve the real ones, decided here rather than at each
/// call site where it could be forgotten.
///
/// See https://support.google.com/admob/answer/6128543 for the test ids.
class AdIds {
  const AdIds._();

  /// Forces test ads from a release build.
  ///
  ///     flutter build apk --release --dart-define=FORCE_TEST_ADS=true
  ///
  /// There is no other safe way to check the ad layout on a phone that already
  /// has the game on it. A debug build cannot be installed over a release one
  /// - it is a lower version code, and forcing it means uninstalling, which
  /// destroys the player's save - so verifying on a real device otherwise
  /// means loading the real units and generating impressions on your own
  /// inventory, which is the exact thing [usingTestAds] exists to prevent.
  static const bool _forceTestAds = bool.fromEnvironment('FORCE_TEST_ADS');

  /// True when this build talks to Google's test units rather than the real
  /// ones. Surfaced so a debug banner can say so out loud.
  static bool get usingTestAds => kDebugMode || _forceTestAds;

  // -- the real units, supplied by the owner --------------------------------

  /// The Android app, from the AdMob console.
  static const String _androidAppId = 'ca-app-pub-8244651657160773~3302542021';
  static const String _androidBanner = 'ca-app-pub-8244651657160773/4695514742';
  static const String _androidInterstitial =
      'ca-app-pub-8244651657160773/9733782106';
  static const String _androidRewarded =
      'ca-app-pub-8244651657160773/4503943052';

  /// iOS has none yet.
  ///
  /// An AdMob app id is per platform: the ids above are registered to the
  /// Android app and are not valid for the iOS one. Serving them there would
  /// fail to fill at best and count as misrepresenting inventory at worst, so
  /// iOS stays on test ads until a second app is registered in the console and
  /// its ids are pasted in here. [adsAreLive] is what the rest of the code
  /// asks, so nothing else needs to know.
  static const String? _iosAppId = null;
  static const String? _iosBanner = null;
  static const String? _iosInterstitial = null;
  static const String? _iosRewarded = null;

  // -- Google's public test units -------------------------------------------

  static const String _testAndroidBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testAndroidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testAndroidRewarded =
      'ca-app-pub-3940256099942544/5224354917';

  static const String _testIosBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testIosInterstitial =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testIosRewarded =
      'ca-app-pub-3940256099942544/1712485313';

  // -- what the app actually asks for ---------------------------------------

  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  /// Whether this build is serving the owner's own inventory.
  ///
  /// False in debug, and false on iOS until that app is registered. When it is
  /// false the ads still work, they are simply Google's test creatives, so the
  /// layout and the flow can be checked without touching real inventory.
  static bool get adsAreLive => !usingTestAds && (!_isIOS || _iosAppId != null);

  static String get banner {
    if (_isIOS) {
      return adsAreLive ? _iosBanner! : _testIosBanner;
    }
    return adsAreLive ? _androidBanner : _testAndroidBanner;
  }

  static String get interstitial {
    if (_isIOS) {
      return adsAreLive ? _iosInterstitial! : _testIosInterstitial;
    }
    return adsAreLive ? _androidInterstitial : _testAndroidInterstitial;
  }

  static String get rewarded {
    if (_isIOS) {
      return adsAreLive ? _iosRewarded! : _testIosRewarded;
    }
    return adsAreLive ? _androidRewarded : _testAndroidRewarded;
  }

  /// The app id, which belongs in the Android manifest and the iOS plist
  /// rather than in code. Kept here so there is one place that knows it, and
  /// so a test can check the manifest still agrees with it.
  static String get androidAppId => _androidAppId;
}
