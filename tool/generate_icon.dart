/// Draws the app icon: the mascot head, flat, on `bg`.
///
///   dart run tool/generate_icon.dart
///
/// Writes the Android mipmaps and the iOS app icon set in place. Pure Dart,
/// no image package: the icon is rasterised here and encoded as PNG with
/// dart:io's zlib. The mascot is never shipped as an image asset inside the
/// app - this file only produces the launcher icon, which the platforms
/// require as a bitmap.
library;

import 'dart:io';
import 'dart:typed_data';

// Colours from section 3.
const int _bg = 0xFF141026;
const int _inkPurple = 0xFF8B5CF0;
const int _inkPurpleHi = 0xFFB47CF5;
const int _inkPink = 0xFFFF9AC1;
const int _eyeWhite = 0xFFFFFFFF;
const int _pupil = 0xFF241C42;

/// Supersampling factor. The icon is drawn this much larger and box filtered
/// down, which is all the antialiasing a flat shape needs.
const int _ss = 4;

class Canvas32 {
  final int w;
  final int h;
  final Uint32List px;

  Canvas32(this.w, this.h) : px = Uint32List(w * h);

  void fillAll(int argb) => px.fillRange(0, px.length, argb);

  void blend(int x, int y, int argb) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final a = (argb >> 24) & 0xFF;
    if (a == 0) return;
    final i = y * w + x;
    if (a == 255) {
      px[i] = argb;
      return;
    }
    final dst = px[i];
    final ia = 255 - a;
    final r = (((argb >> 16) & 0xFF) * a + ((dst >> 16) & 0xFF) * ia) ~/ 255;
    final g = (((argb >> 8) & 0xFF) * a + ((dst >> 8) & 0xFF) * ia) ~/ 255;
    final b = ((argb & 0xFF) * a + (dst & 0xFF) * ia) ~/ 255;
    px[i] = 0xFF000000 | (r << 16) | (g << 8) | b;
  }

  void ellipse(double cx, double cy, double rx, double ry, int argb) {
    final x0 = (cx - rx).floor().clamp(0, w - 1);
    final x1 = (cx + rx).ceil().clamp(0, w - 1);
    final y0 = (cy - ry).floor().clamp(0, h - 1);
    final y1 = (cy + ry).ceil().clamp(0, h - 1);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final dx = (x + 0.5 - cx) / rx;
        final dy = (y + 0.5 - cy) / ry;
        if (dx * dx + dy * dy <= 1) blend(x, y, argb);
      }
    }
  }

  /// Rounded rectangle with independent top and bottom radii.
  void roundedRect(
    double left,
    double top,
    double width,
    double height,
    double topRadius,
    double bottomRadius,
    int argb,
  ) {
    final right = left + width;
    final bottom = top + height;
    final x0 = left.floor().clamp(0, w - 1);
    final x1 = right.ceil().clamp(0, w - 1);
    final y0 = top.floor().clamp(0, h - 1);
    final y1 = bottom.ceil().clamp(0, h - 1);

    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final px0 = x + 0.5;
        final py0 = y + 0.5;
        if (px0 < left || px0 > right || py0 < top || py0 > bottom) continue;

        final r = py0 < top + topRadius ? topRadius : bottomRadius;
        final cx = px0 < left + r
            ? left + r
            : (px0 > right - r ? right - r : px0);
        final cy = py0 < top + topRadius
            ? top + topRadius
            : (py0 > bottom - bottomRadius ? bottom - bottomRadius : py0);
        final dx = px0 - cx;
        final dy = py0 - cy;
        if (dx * dx + dy * dy <= r * r) blend(x, y, argb);
      }
    }
  }

  /// Box filter down to [size].
  Canvas32 downsample(int size) {
    final out = Canvas32(size, size);
    final factor = w ~/ size;
    final area = factor * factor;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        var r = 0, g = 0, b = 0;
        for (var sy = 0; sy < factor; sy++) {
          for (var sx = 0; sx < factor; sx++) {
            final c = px[(y * factor + sy) * w + (x * factor + sx)];
            r += (c >> 16) & 0xFF;
            g += (c >> 8) & 0xFF;
            b += c & 0xFF;
          }
        }
        out.px[y * size + x] =
            0xFF000000 | ((r ~/ area) << 16) | ((g ~/ area) << 8) | (b ~/ area);
      }
    }
    return out;
  }
}

int _withAlpha(int argb, double alpha) =>
    ((alpha * 255).round().clamp(0, 255) << 24) | (argb & 0x00FFFFFF);

/// Draws the mascot head, flat, filling a square of [size] pixels.
Canvas32 drawIcon(int size) {
  final s = size * _ss;
  final c = Canvas32(s, s)..fillAll(_bg);
  double u(double f) => f * s;

  // Arms first, so the head overlaps their tops.
  // The head bottom lands at 0.75, so the arms have to run past that to read
  // as arms rather than as a shadow under the blob.
  const armX = <double>[0.295, 0.5, 0.705];
  for (final x in armX) {
    c.roundedRect(
      u(x - 0.049),
      u(0.60),
      u(0.098),
      u(0.265),
      u(0.049),
      u(0.049),
      _inkPurple,
    );
  }
  for (final x in armX) {
    c.ellipse(u(x), u(0.805), u(0.019), u(0.019), _withAlpha(_inkPink, 0.85));
  }

  // Head: roughly 1.15 wide to 1.0 tall.
  const headW = 0.66;
  const headH = 0.575;
  const headL = (1 - headW) / 2;
  const headT = 0.175;
  c.roundedRect(
    u(headL),
    u(headT),
    u(headW),
    u(headH),
    u(headW / 2),
    u(headW * 0.34),
    _inkPurple,
  );

  // Highlight across the upper third. Kept well inside the head outline: the
  // top corner radius is headW / 2, so anything wider than about 0.20 pokes
  // out of the dome and reads as a halo.
  c.ellipse(
    u(0.5),
    u(0.325),
    u(0.20),
    u(0.105),
    _withAlpha(_inkPurpleHi, 0.62),
  );

  // Cheeks.
  c.ellipse(u(0.30), u(0.485), u(0.052), u(0.032), _withAlpha(_inkPink, 0.4));
  c.ellipse(u(0.70), u(0.485), u(0.052), u(0.032), _withAlpha(_inkPink, 0.4));

  // Eyes.
  for (final ex in <double>[0.395, 0.605]) {
    c.ellipse(u(ex), u(0.415), u(0.072), u(0.082), _eyeWhite);
    c.ellipse(u(ex), u(0.428), u(0.034), u(0.038), _pupil);
    c.ellipse(
      u(ex - 0.014),
      u(0.408),
      u(0.014),
      u(0.015),
      _withAlpha(_eyeWhite, 0.9),
    );
  }

  return c.downsample(size);
}

// ---------------------------------------------------------------------------
// PNG encoding
// ---------------------------------------------------------------------------

Uint8List encodePng(Canvas32 c) {
  final raw = BytesBuilder();
  for (var y = 0; y < c.h; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < c.w; x++) {
      final p = c.px[y * c.w + x];
      raw
        ..addByte((p >> 16) & 0xFF)
        ..addByte((p >> 8) & 0xFF)
        ..addByte(p & 0xFF)
        ..addByte((p >> 24) & 0xFF);
    }
  }

  final out = BytesBuilder()
    ..add(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  final ihdr = BytesBuilder()
    ..add(_be32(c.w))
    ..add(_be32(c.h))
    ..add(<int>[
      8,
      6,
      0,
      0,
      0,
    ]); // 8 bit, RGBA, deflate, no filter, no interlace
  out.add(_chunk('IHDR', ihdr.takeBytes()));

  final compressed = ZLibCodec(level: 9).encode(raw.takeBytes());
  out.add(_chunk('IDAT', Uint8List.fromList(compressed)));
  out.add(_chunk('IEND', Uint8List(0)));
  return out.takeBytes();
}

List<int> _be32(int v) => <int>[
  (v >> 24) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 8) & 0xFF,
  v & 0xFF,
];

Uint8List _chunk(String type, Uint8List data) {
  final b = BytesBuilder()
    ..add(_be32(data.length))
    ..add(type.codeUnits)
    ..add(data);
  final body = b.takeBytes();
  final crc = _crc32(body.sublist(4));
  final out = BytesBuilder()
    ..add(body)
    ..add(_be32(crc));
  return out.takeBytes();
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

// ---------------------------------------------------------------------------

void write(String path, int size) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(encodePng(drawIcon(size)));
  stdout.writeln('  $path (${size}x$size)');
}

void main() {
  stdout.writeln('Android');
  const android = <String, int>{
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };
  android.forEach(write);

  stdout.writeln('iOS');
  const iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  const ios = <String, int>{
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };
  ios.forEach((name, size) {
    if (File('$iosDir/$name').existsSync()) write('$iosDir/$name', size);
  });

  // The iOS launch storyboard centres this over the same background colour,
  // so the square edges are invisible and the handover to the first Flutter
  // frame has nothing to flash.
  stdout.writeln('iOS launch image');
  const launchDir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
  const launch = <String, int>{
    'LaunchImage.png': 160,
    'LaunchImage@2x.png': 320,
    'LaunchImage@3x.png': 480,
  };
  launch.forEach((name, size) {
    if (Directory(launchDir).existsSync()) write('$launchDir/$name', size);
  });

  stdout.writeln('Store');
  write('store/icon_512.png', 512);
  write('store/icon_1024.png', 1024);
  stdout.writeln('done');
}
