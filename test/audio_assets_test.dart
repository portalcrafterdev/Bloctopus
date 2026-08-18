import 'dart:io';

import 'package:blocktopus/game/audio.dart';
import 'package:flutter_test/flutter_test.dart';

/// The game shipped silent once: every `play` call was wired up correctly and
/// there were simply no files behind them, and nothing failed because the
/// audio service is designed to stay quiet rather than throw. So the presence
/// of the files is the thing worth asserting.
void main() {
  final dir = Directory('assets/audio');

  const sfx = <String>[
    Sfx.pickup,
    Sfx.place,
    Sfx.invalid,
    Sfx.combo,
    Sfx.booster,
    Sfx.ink,
    Sfx.star,
    Sfx.levelWin,
    Sfx.levelFail,
    Sfx.blub,
    Sfx.tap,
  ];

  File file(String key) => File('${dir.path}/$key.wav');

  test('every sound in section 11.1 exists', () {
    for (final key in sfx) {
      expect(file(key).existsSync(), isTrue, reason: '$key is missing');
    }
    for (final key in <String>[Music.menu, Music.game]) {
      expect(file(key).existsSync(), isTrue, reason: '$key is missing');
    }
  });

  test('the pitch ladder has all eight rungs', () {
    for (var step = 1; step <= 8; step++) {
      final f = file(Sfx.clear(step));
      expect(f.existsSync(), isTrue, reason: 'clear_$step is missing');
      expect(f.lengthSync(), greaterThan(1000), reason: 'clear_$step is empty');
    }
  });

  test('the ladder clamps rather than running off the end', () {
    expect(Sfx.clear(0), 'clear_1');
    expect(Sfx.clear(1), 'clear_1');
    expect(Sfx.clear(8), 'clear_8');
    expect(Sfx.clear(99), 'clear_8');
  });

  test('every file is inside its section 11.3 budget', () {
    for (final key in <String>[
      ...sfx,
      for (var i = 1; i <= 8; i++) 'clear_$i',
    ]) {
      expect(
        file(key).lengthSync(),
        lessThanOrEqualTo(40 * 1024),
        reason: '$key is over the 40 KB per sound budget',
      );
    }
    for (final key in <String>[Music.menu, Music.game]) {
      expect(
        file(key).lengthSync(),
        lessThanOrEqualTo(1200 * 1024),
        reason: '$key is over the 1.2 MB per loop budget',
      );
    }
  });

  _preloadCoverage();

  test('the files are real PCM wav, not empty placeholders', () {
    for (final key in <String>[Sfx.place, Sfx.clear(1), Music.game]) {
      final bytes = file(key).readAsBytesSync();
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      // Mono, 16 bit. Byte 22 is the channel count, byte 34 the bit depth.
      expect(bytes[22], 1, reason: '$key is not mono');
      expect(bytes[34], 16, reason: '$key is not 16 bit');
    }
  });
}

/// Every effect is preloaded at startup, one player per sound, so that playing
/// it costs a rewind and a native trigger rather than resolving and preparing
/// the asset again. The cost of that design is that a sound missing from the
/// preload list has no player at all and is skipped in silence, with nothing
/// throwing and no failure recorded. These two tests are what stop a new sound
/// being added and never heard.
void _preloadCoverage() {
  final dir = Directory('assets/audio');

  test('every preloaded key has a file behind it', () {
    for (final key in AudioService.preloadedKeys) {
      expect(
        File('${dir.path}/$key.wav').existsSync(),
        isTrue,
        reason: '$key is preloaded but has no file',
      );
    }
  });

  test('every shipped effect is preloaded', () {
    // Music is deliberately excluded: it streams from its own looping player
    // rather than being held in the effects pool.
    final music = <String>{Music.menu, Music.game};
    final onDisk = dir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.wav'))
        .map((n) => n.substring(0, n.length - 4))
        .where((n) => !music.contains(n))
        .toSet();

    expect(
      onDisk.difference(AudioService.preloadedKeys.toSet()),
      isEmpty,
      reason:
          'these sounds ship but are never warmed up, so the first play stalls',
    );
  });
}
