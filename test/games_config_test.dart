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

  group('the leaderboards', () {
    test('every board has an id for at least one platform', () {
      // A board with neither id is dead weight: it can never be submitted to
      // and never appears, so it is a listing in the Play Console that the
      // game silently ignores.
      for (final board in GameLeaderboard.values) {
        expect(
          board.android ?? board.ios,
          isNotNull,
          reason: '${board.name} has no id on either platform',
        );
      }
    });

    test('no two boards share an id', () {
      // Copy and paste is the obvious way to get this wrong, and the symptom
      // is not an error: two metrics quietly overwrite each other on one
      // board while another never receives a score.
      final ids = GameLeaderboard.values
          .map((b) => b.android)
          .whereType<String>()
          .toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'two leaderboards point at the same Play Console board',
      );
    });

    test('android ids need the project id to be reachable', () {
      // GamesIds.available gates every call, and on Android it is false
      // without the project id. Leaderboard ids on their own would do
      // nothing, so this catches half a configuration.
      final anyAndroid = GameLeaderboard.values.any((b) => b.android != null);
      if (anyAndroid) {
        expect(
          GamesIds.playGamesProjectId,
          isNotNull,
          reason:
              'android leaderboard ids are set but playGamesProjectId is '
              'null, so sign in never starts and none of them are reachable',
        );
      }
    });

    test('ids are Play Console ids, not names', () {
      // Play issues opaque ids beginning with Cgk. A human readable string
      // here means someone pasted the leaderboard's display name instead,
      // which fails at submit time with a generic error.
      for (final board in GameLeaderboard.values) {
        final android = board.android;
        if (android != null) {
          expect(
            android.startsWith('Cgk'),
            isTrue,
            reason:
                '${board.name} android id "$android" does not look like a '
                'Play Console leaderboard id',
          );
        }
      }
    });
  });

  group('against the Play Console export', () {
    // test/fixtures/games-ids.xml is the console's own games-ids.xml, saved
    // verbatim. Every id in the app is checked against it, because a wrong id
    // is invisible at runtime: Play accepts an unlock for an achievement it
    // has never heard of and does nothing with it.
    final export = File('test/fixtures/games-ids.xml').readAsStringSync();

    String? idFor(String name) => RegExp(
      'name="$name"[^>]*>([^<]*)<',
    ).firstMatch(export)?.group(1);

    /// enum name -> the console's resource suffix. tideWalker -> tide_walker.
    String snake(String camel) => camel
        .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')
        .toLowerCase();

    test('the fixture is the right project', () {
      expect(idFor('app_id'), GamesIds.playGamesProjectId);
      expect(idFor('package_name'), 'com.portalcrafter.blocktopus');
    });

    test('every achievement id matches the console', () {
      for (final a in GameAchievement.values) {
        expect(
          a.android,
          idFor('achievement_${snake(a.name)}'),
          reason: '${a.name} does not match the console export',
        );
      }
    });

    test('every leaderboard id matches the console', () {
      for (final b in GameLeaderboard.values) {
        expect(
          b.android,
          idFor('leaderboard_${snake(b.name)}'),
          reason: '${b.name} does not match the console export',
        );
      }
    });

    test('the app knows about every achievement the console has', () {
      // The other direction: a board created in the console and never added
      // here is one the game can never unlock.
      final inExport = RegExp(
        r'name="achievement_([a-z_]+)"',
      ).allMatches(export).map((m) => m.group(1)).toSet();
      final inApp = GameAchievement.values.map((a) => snake(a.name)).toSet();
      expect(
        inExport.difference(inApp),
        isEmpty,
        reason: 'achievements exist in Play Console that the game never '
            'unlocks',
      );
    });

    test('no two achievements share an id', () {
      final ids = GameAchievement.values
          .map((a) => a.android)
          .whereType<String>()
          .toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('against the console metadata csv', () {
    // The Play import bundle's own AchievementsMetadata.csv, saved verbatim.
    // Its columns are: Name, Description, Incremental, Steps Needed, Initial
    // State, Points, List Order - no header row, and no quoting, which is why
    // the importer forbids commas in names and descriptions.
    final rows = File('test/fixtures/AchievementsMetadata.csv')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .map((l) => l.split(','))
        .toList();

    /// "First Ripple" -> firstRipple, to match the enum.
    String camel(String name) {
      final parts = name.trim().toLowerCase().split(RegExp(r'\s+'));
      return parts.first +
          parts
              .skip(1)
              .map((p) => p[0].toUpperCase() + p.substring(1))
              .join();
    }

    test('the fixture covers every achievement', () {
      expect(rows.length, GameAchievement.values.length);
      expect(
        rows.map((r) => camel(r[0])).toSet(),
        GameAchievement.values.map((a) => a.name).toSet(),
      );
    });

    test('incremental flags match', () {
      for (final row in rows) {
        final a = GameAchievement.values.byName(camel(row[0]));
        final incrementalInConsole = row[2].trim().toLowerCase() == 'true';
        expect(
          a.isIncremental,
          incrementalInConsole,
          reason:
              '${a.name}: the console says incremental=$incrementalInConsole. '
              'Calling unlock on an incremental achievement does not complete '
              'it, and setSteps on a standard one fails.',
        );
      }
    });

    test('step targets match', () {
      for (final row in rows) {
        final a = GameAchievement.values.byName(camel(row[0]));
        final stepsInConsole = int.tryParse(row[3].trim()) ?? 0;
        expect(
          a.steps,
          stepsInConsole,
          reason:
              '${a.name} reports progress against ${a.steps} but the console '
              'needs $stepsInConsole, so it would unlock at the wrong moment',
        );
      }
    });

    test('the descriptions are quoted in the code', () {
      // Every rule in achievements.dart carries its console description as a
      // comment. This checks the descriptions still parse as the importer
      // requires - no commas, since the CSV has no quoting - so a later edit
      // in the console cannot silently break the next import.
      for (final row in rows) {
        expect(row.length, 7, reason: '${row[0]} has the wrong column count');
        expect(row[1].trim(), isNotEmpty);
      }
    });
  });

  group('the games service', () {
    test('never fakes a signed in player', () {
      // There was briefly a --dart-define preview that filled `player` in so
      // the signed in layout could be seen before sign in worked. It is gone.
      // A build that claims someone is signed in when nobody is would submit
      // nothing, unlock nothing and report no error, which looks exactly like
      // a broken integration.
      final source = File('lib/games/games_service.dart').readAsStringSync();
      expect(
        source.contains('FAKE_GAMES_USER'),
        isFalse,
        reason: 'the fake player preview must not come back',
      );
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
