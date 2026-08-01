/// Offline audio generator. Never shipped, never runs on device.
///
///   dart run tool/generate_audio.dart
///
/// Synthesises every sound in section 11.1 from scratch: sine partials, noise
/// bursts and envelopes, written straight out as PCM. Nothing here is sampled,
/// recorded or derived from any other game, which is the requirement in
/// sections 11.3 and 16.
///
/// These are honest placeholders, not a substitute for commissioned audio.
/// They are tuned to be soft and non-fatiguing, and the pitch ladder in
/// section 11.2 is real: `clear_1` to `clear_8` walk a C major scale, so three
/// lines at once genuinely arpeggiate.
///
/// Two deviations from section 11.3, both forced and both documented in
/// assets/audio/README.md:
///
///   * Format is WAV, not OGG/M4A. Encoding either one needs a codec that
///     pure Dart does not have, and shelling out to ffmpeg would make the
///     build depend on a tool that is not otherwise required.
///   * Sample rate is 22.05kHz, not 44.1kHz. WAV is uncompressed, so 44.1kHz
///     would put the longer cues over the 40 KB per file budget. 22.05kHz
///     reproduces everything up to 11kHz, which is well above the highest
///     partial any of these sounds carries.
///
/// Both go away when real audio is commissioned: drop OGG/M4A files with the
/// same names into assets/audio and change `_ext` in lib/game/audio.dart.
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int kRate = 22050;

/// Peak each file is normalised to. Leaves headroom so that layered sounds -
/// a clear plus a combo plus music - do not clip against each other.
const double kPeak = 0.72;

void main(List<String> args) {
  final outDir = Directory('assets/audio');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final sounds = <String, List<double>>{
    'pickup': _pickup(),
    'place': _place(),
    'invalid': _invalid(),
    'combo': _combo(),
    'booster': _booster(),
    'ink': _ink(),
    'star': _star(),
    'level_win': _levelWin(),
    'level_fail': _levelFail(),
    'blub': _blub(),
    'tap': _tap(),
    for (var i = 1; i <= 8; i++) 'clear_$i': _clear(i),
    'music_menu': _musicMenu(),
    'music_game': _musicGame(),
  };

  var total = 0;
  final oversized = <String>[];
  final names = sounds.keys.toList()..sort();
  for (final name in names) {
    final bytes = _wav(sounds[name]!);
    File('${outDir.path}/$name.wav').writeAsBytesSync(bytes);
    total += bytes.length;

    final isMusic = name.startsWith('music_');
    final budget = isMusic ? 1200 * 1024 : 40 * 1024;
    if (bytes.length > budget) oversized.add(name);
    stdout.writeln(
      '  ${name.padRight(12)} ${_kb(bytes.length).padLeft(9)}'
      '${bytes.length > budget ? '  OVER BUDGET' : ''}',
    );
  }

  stdout.writeln('\n  ${names.length} files, ${_kb(total)} total');
  if (oversized.isNotEmpty) {
    stderr.writeln('  over budget: ${oversized.join(', ')}');
    exitCode = 1;
  }
}

String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KB';

// ---------------------------------------------------------------------------
// Voices
// ---------------------------------------------------------------------------

/// Note frequencies. The ladder in section 11.2 names C, D, E, F, G, A, B, C,
/// so it is a major scale rather than the chromatic run the same sentence also
/// mentions. The note names win: a scale is what actually sounds like a rising
/// arpeggio when three of its steps land 70ms apart.
const double _c5 = 523.25;
const List<double> _scale = <double>[
  _c5, // C5
  587.33, // D5
  659.25, // E5
  698.46, // F5
  783.99, // G5
  880.00, // A5
  987.77, // B5
  1046.50, // C6
];

/// A struck bar, the marimba-ish voice the whole game is built on: a sine
/// fundamental plus a quiet partial four octaves-and-a-bit up, which is what
/// gives a wooden bar its knock without any percussion.
List<double> _bar(double freq, double seconds, {double gain = 1}) {
  final n = (seconds * kRate).round();
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final t = i / kRate;
    final env = exp(-t * 7.5) * _attack(t, 0.004);
    final partial = exp(-t * 16) * _attack(t, 0.002);
    out[i] =
        gain *
        (sin(2 * pi * freq * t) * env +
            0.28 * sin(2 * pi * freq * 3.94 * t) * partial);
  }
  return out;
}

/// A soft sine blip with an optional pitch glide, used for the small UI cues.
List<double> _blip(
  double from,
  double to,
  double seconds, {
  double decay = 18,
  double gain = 1,
}) {
  final n = (seconds * kRate).round();
  final out = List<double>.filled(n, 0);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / kRate;
    final k = n == 1 ? 0.0 : i / (n - 1);
    final freq = from + (to - from) * k;
    phase += 2 * pi * freq / kRate;
    out[i] = gain * sin(phase) * exp(-t * decay) * _attack(t, 0.003);
  }
  return out;
}

/// Filtered noise, for the wet edge on `ink` and the body of `place`.
List<double> _noise(double seconds, {double decay = 40, double gain = 1}) {
  final n = (seconds * kRate).round();
  final rnd = Random(7);
  final out = List<double>.filled(n, 0);
  var lp = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / kRate;
    // One pole low pass, so it reads as water rather than static.
    lp += (rnd.nextDouble() * 2 - 1 - lp) * 0.16;
    out[i] = gain * lp * exp(-t * decay);
  }
  return out;
}

double _attack(double t, double seconds) => t >= seconds ? 1 : t / seconds;

// ---------------------------------------------------------------------------
// The sounds
// ---------------------------------------------------------------------------

/// The pitch ladder. Step 1 is C5, step 8 is C6.
List<double> _clear(int step) {
  final freq = _scale[(step - 1).clamp(0, _scale.length - 1)];
  // Higher rungs ring very slightly shorter, so a fast arpeggio stays clean.
  final seconds = 0.42 - (step - 1) * 0.012;
  return _mix([
    _bar(freq, seconds),
    // A fifth underneath at low level: body, not a second note.
    _bar(freq * 0.667, seconds * 0.8, gain: 0.22),
  ]);
}

List<double> _pickup() => _blip(420, 640, 0.10, decay: 26, gain: 0.55);

List<double> _place() => _mix([
  _blip(220, 165, 0.13, decay: 30),
  _noise(0.05, decay: 90, gain: 0.30),
]);

/// Section 11.1 asks for this to be quiet and non-punishing, so it is a soft
/// low thud with no high content at all rather than a buzz.
List<double> _invalid() => _blip(150, 120, 0.14, decay: 22, gain: 0.42);

List<double> _tap() => _blip(660, 660, 0.06, decay: 45, gain: 0.35);

/// A tiny bubble: pitch rises then pops.
List<double> _blub() => _mix([
  _blip(300, 900, 0.11, decay: 28, gain: 0.34),
  _noise(0.02, decay: 150, gain: 0.12),
]);

/// Wet pop for Ink Blast.
List<double> _ink() => _mix([
  _blip(700, 180, 0.16, decay: 24),
  _noise(0.09, decay: 45, gain: 0.42),
]);

List<double> _booster() => _mix([
  _bar(_scale[0], 0.26, gain: 0.7),
  _delay(_bar(_scale[4], 0.30, gain: 0.7), 0.07),
]);

/// Layered on top of a clear at streak 3+, so it is a chord rather than a
/// melody: it has to sit under whatever rung of the ladder is playing.
List<double> _combo() => _mix([
  _bar(_scale[0] * 2, 0.34, gain: 0.34),
  _bar(_scale[2] * 2, 0.34, gain: 0.28),
  _bar(_scale[4] * 2, 0.34, gain: 0.24),
]);

/// One bright ding. The result screen plays this three times, 220ms apart.
List<double> _star() =>
    _mix([_bar(1046.50, 0.34, gain: 0.8), _bar(1567.98, 0.26, gain: 0.3)]);

/// A rising four note figure, C E G C.
List<double> _levelWin() => _mix([
  _bar(_scale[0], 0.30, gain: 0.7),
  _delay(_bar(_scale[2], 0.30, gain: 0.7), 0.10),
  _delay(_bar(_scale[4], 0.30, gain: 0.7), 0.20),
  _delay(_bar(_scale[7], 0.44, gain: 0.8), 0.30),
]);

/// Gentle, never harsh: two notes falling a whole tone, soft attack.
List<double> _levelFail() => _mix([
  _bar(392.00, 0.34, gain: 0.5), // G4
  _delay(_bar(349.23, 0.46, gain: 0.5), 0.14), // F4
]);

// ---------------------------------------------------------------------------
// Music
// ---------------------------------------------------------------------------

/// Both loops are built so the join is inaudible: the pad frequencies are
/// snapped to whole cycles per loop, and every marimba note decays well before
/// the end. Underwater tone per section 11.3 - soft marimba over low pads,
/// nothing that drives urgency.
List<double> _pad(double seconds, List<double> freqs, {double gain = 0.2}) {
  final n = (seconds * kRate).round();
  final out = List<double>.filled(n, 0);
  for (final raw in freqs) {
    // Snap to an exact number of cycles across the loop so it wraps cleanly.
    final cycles = max(1, (raw * seconds).round());
    final freq = cycles / seconds;
    for (var i = 0; i < n; i++) {
      final t = i / kRate;
      // A slow swell, also an exact number of cycles across the loop.
      final lfo = 0.62 + 0.38 * sin(2 * pi * (2 / seconds) * t);
      out[i] += gain * lfo * sin(2 * pi * freq * t) / freqs.length;
    }
  }
  return out;
}

List<double> _sparse(
  double seconds,
  List<double> notes,
  List<double> times, {
  double gain = 0.5,
}) {
  final n = (seconds * kRate).round();
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < times.length; i++) {
    final note = _bar(notes[i % notes.length], 1.1, gain: gain);
    final start = (times[i] * kRate).round();
    for (var j = 0; j < note.length && start + j < n; j++) {
      out[start + j] += note[j];
    }
  }
  return out;
}

/// 16 seconds. A pentatonic figure over a low pad.
List<double> _musicMenu() {
  const seconds = 16.0;
  return _mix([
    _pad(seconds, <double>[130.81, 196.00, 261.63], gain: 0.30), // C3 G3 C4
    _sparse(
      seconds,
      <double>[523.25, 587.33, 783.99, 659.25, 587.33],
      <double>[0.4, 2.1, 4.0, 6.3, 8.2, 10.4, 12.1, 14.3],
      gain: 0.34,
    ),
  ]);
}

/// 16 seconds, calmer and lower than the menu: it plays under the whole game
/// and must not compete with the pitch ladder.
List<double> _musicGame() {
  const seconds = 16.0;
  return _mix([
    _pad(seconds, <double>[110.00, 164.81, 220.00], gain: 0.32), // A2 E3 A3
    _sparse(
      seconds,
      <double>[440.00, 523.25, 587.33, 493.88],
      <double>[1.0, 3.6, 5.9, 8.8, 11.2, 13.9],
      gain: 0.26,
    ),
  ]);
}

// ---------------------------------------------------------------------------
// Mixing and encoding
// ---------------------------------------------------------------------------

List<double> _delay(List<double> src, double seconds) {
  final pad = (seconds * kRate).round();
  return <double>[...List<double>.filled(pad, 0), ...src];
}

List<double> _mix(List<List<double>> parts) {
  final n = parts.fold<int>(0, (a, p) => max(a, p.length));
  final out = List<double>.filled(n, 0);
  for (final p in parts) {
    for (var i = 0; i < p.length; i++) {
      out[i] += p[i];
    }
  }
  return out;
}

/// Normalises to [kPeak] and fades the last few milliseconds, so no file ends
/// on a non-zero sample and clicks on playback.
Uint8List _wav(List<double> samples) {
  var peak = 0.0;
  for (final s in samples) {
    peak = max(peak, s.abs());
  }
  final scale = peak == 0 ? 0.0 : kPeak / peak;

  final fade = (0.004 * kRate).round();
  final n = samples.length;
  final pcm = Int16List(n);
  for (var i = 0; i < n; i++) {
    var v = samples[i] * scale;
    if (i < fade) v *= i / fade;
    if (i >= n - fade) v *= (n - 1 - i) / fade;
    pcm[i] = (v.clamp(-1.0, 1.0) * 32767).round();
  }

  const headerBytes = 44;
  final dataBytes = n * 2;
  final out = BytesBuilder();
  void str(String s) => out.add(s.codeUnits);
  void u32(int v) => out.add(<int>[
    v & 0xFF,
    (v >> 8) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 24) & 0xFF,
  ]);
  void u16(int v) => out.add(<int>[v & 0xFF, (v >> 8) & 0xFF]);

  str('RIFF');
  u32(headerBytes - 8 + dataBytes);
  str('WAVE');
  str('fmt ');
  u32(16); // PCM chunk size
  u16(1); // PCM
  u16(1); // mono
  u32(kRate);
  u32(kRate * 2); // byte rate
  u16(2); // block align
  u16(16); // bits per sample
  str('data');
  u32(dataBytes);
  out.add(pcm.buffer.asUint8List());
  return out.toBytes();
}
