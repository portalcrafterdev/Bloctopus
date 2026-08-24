import 'dart:io';

import 'package:blocktopus/games/games_ids.dart';
import 'package:flutter_test/flutter_test.dart';

/// Play Games and Game Center configuration is spread across the manifest, a
/// string resource, an entitlements file and the Xcode project, and none of
/// it fails loudly when it drifts: sign in just returns a generic error that
/// looks the same as a player declining. So the agreement is asserted here.
void main() {
  group('android manifest', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');

    test('declares the Play Games app id', () {
      // The Games SDK reads this at sign in and gives up without it.
      expect(
        manifest.readAsStringSync().contains(
          'com.google.android.gms.games.APP_ID',
        ),
        isTrue,
      );
    });

    test('declares the Play Services version', () {
      // The Games SDK checks the version on the device against this before
      // doing anything, so it is required rather than advisory.
      expect(
        manifest.readAsStringSync().contains(
          '@integer/google_play_services_version',
        ),
        isTrue,
      );
    });

    test('reads the id from a string resource, not a literal', () {
      // A bare twelve digit number in android:value is parsed as an integer
      // and overflows, and the SDK then reports a missing app id. This is the
      // single most common way to get this wrong, and it is invisible.
      expect(
        manifest.readAsStringSync().contains(
          'android:value="@string/game_services_project_id"',
        ),
        isTrue,
      );
    });
  });

  group('the project id', () {
    final strings = File('android/app/src/main/res/values/strings.xml');

    test('exists as a string resource', () {
      expect(
        strings.readAsStringSync().contains('name="game_services_project_id"'),
        isTrue,
      );
    });

    test('matches the one the code believes in', () {
      final declared = GamesIds.playGamesProjectId;
      final xml = strings.readAsStringSync();
      final resource = RegExp(
        r'name="game_services_project_id"[^>]*>([^<]*)<',
      ).firstMatch(xml)?.group(1);

      expect(resource, isNotNull, reason: 'the resource has no value');

      if (declared == null) {
        // Not configured yet. The only thing worth asserting is that the two
        // halves have not been half-filled in: a real id in the manifest with
        // GamesIds still null means the button is disabled on a build that
        // could have signed in.
        expect(
          resource,
          '000000000000',
          reason:
              'strings.xml has a real project id but '
              'GamesIds.playGamesProjectId is still null, so nothing will '
              'ever call the SDK',
        );
      } else {
        expect(
          resource,
          declared,
          reason:
              'strings.xml and GamesIds.playGamesProjectId have drifted '
              'apart, which shows up as sign in failing with a generic error',
        );
      }
    });
  });

  group('ios', () {
    test('has a Game Center entitlement', () {
      final entitlements = File('ios/Runner/Runner.entitlements');
      expect(entitlements.existsSync(), isTrue);
      expect(
        entitlements.readAsStringSync().contains(
          'com.apple.developer.game-center',
        ),
        isTrue,
      );
    });

    test('the Xcode project actually signs with it', () {
      // The file on disk does nothing on its own. Without this build setting
      // the entitlement is not in the signed binary and Game Center reports
      // the player as unauthenticated, with no error anywhere to explain it.
      final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj');
      final uses = 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'
          .allMatches(pbxproj.readAsStringSync())
          .length;
      expect(
        uses,
        3,
        reason:
            'all three Runner configurations - Debug, Profile and Release - '
            'need it, or Game Center works in one build and not another',
      );
    });
  });
}
