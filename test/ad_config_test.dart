import 'dart:io';

import 'package:blocktopus/ads/ad_ids.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ad configuration lives in three places that have to agree, and nothing at
/// runtime tells you when they stop agreeing: a wrong app id does not crash or
/// warn, it just quietly never fills, which looks identical to having no
/// advertisers. So the agreement is asserted here instead.
void main() {
  group('android manifest', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');

    test('declares the AdMob app id', () {
      // Without this meta-data the Google Mobile Ads SDK throws on startup,
      // so its absence is a crash on launch rather than a missing ad.
      final xml = manifest.readAsStringSync();
      expect(
        xml.contains('com.google.android.gms.ads.APPLICATION_ID'),
        isTrue,
        reason: 'the SDK raises at startup without this',
      );
    });

    test('the id in the manifest is the one the code believes in', () {
      final xml = manifest.readAsStringSync();
      expect(
        xml.contains(AdIds.androidAppId),
        isTrue,
        reason:
            'the manifest and AdIds.androidAppId have drifted apart, which '
            'shows up as ads that never fill rather than as an error',
      );
    });
  });

  group('ios', () {
    test('Info.plist carries a GADApplicationIdentifier', () {
      // Same story as Android, except the iOS SDK is stricter: it raises on
      // launch, so a missing key here is a crash on every start.
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist.contains('GADApplicationIdentifier'), isTrue);
    });
  });

  group('unit ids', () {
    test('the three formats are three different units', () {
      // Pasting the same unit into two formats is an easy slip and a quiet
      // one: the ad still loads, it is simply reported against the wrong
      // placement forever.
      final ids = <String>{AdIds.banner, AdIds.interstitial, AdIds.rewarded};
      expect(ids.length, 3);
    });

    test('a debug build never touches the real units', () {
      // This is the one that protects the account rather than the code.
      // Generating impressions or clicks on your own live inventory is
      // invalid traffic, and the penalty is the AdMob account, not the app.
      // Tests run in debug, so this asserts the live rule as it stands.
      expect(AdIds.usingTestAds, isTrue);
      expect(AdIds.adsAreLive, isFalse);
      for (final id in <String>[
        AdIds.banner,
        AdIds.interstitial,
        AdIds.rewarded,
      ]) {
        expect(
          id.startsWith('ca-app-pub-3940256099942544/'),
          isTrue,
          reason: '$id is not one of Google\'s test units',
        );
      }
    });
  });
}
