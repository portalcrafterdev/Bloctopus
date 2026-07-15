/// Piece and shape library.
///
/// Pure Dart. No Flutter imports: this file is consumed by the offline level
/// generator (`tool/generate_levels.dart`) and by the solver.
library;

/// Number of colours in the block palette. The palette itself lives in
/// `app/theme.dart`; pure logic only ever carries the index.
const int kPaletteSize = 7;

/// A shape occupies a `w` x `h` bounding box. `cells` holds the offsets that
/// are filled, encoded as `dy * w + dx`.
class Shape {
  final int id;
  final String name;
  final int w;
  final int h;
  final List<int> cells;

  /// `w * h` lookup table for "is this box offset part of the shape". The
  /// solver asks this millions of times per level, so it must not be a scan
  /// over [cells].
  final List<bool> mask;

  Shape(this.id, this.name, this.w, this.h, this.cells)
    : mask = _maskOf(w, h, cells);

  static List<bool> _maskOf(int w, int h, List<int> cells) {
    final m = List<bool>.filled(w * h, false);
    for (final c in cells) {
      m[c] = true;
    }
    return m;
  }

  /// True when the box offset `(dx, dy)` is part of this shape.
  bool covers(int dx, int dy) {
    if (dx < 0 || dy < 0 || dx >= w || dy >= h) return false;
    return mask[dy * w + dx];
  }

  int get size => cells.length;

  int dx(int i) => cells[i] % w;

  int dy(int i) => cells[i] ~/ w;

  @override
  String toString() => 'Shape($id, $name)';
}

Shape _shape(int id, String name, List<String> rows) {
  final h = rows.length;
  final w = rows.first.length;
  final cells = <int>[];
  for (var y = 0; y < h; y++) {
    assert(rows[y].length == w, 'ragged shape $name');
    for (var x = 0; x < w; x++) {
      if (rows[y][x] == '#') cells.add(y * w + x);
    }
  }
  assert(cells.isNotEmpty, 'empty shape $name');
  return Shape(id, name, w, h, cells);
}

/// The shape library. Indices are stable and are referenced by level
/// `shapePool` values, so never reorder or remove an entry. Append only.
///
/// There is no rotation in this game, so every orientation is its own shape.
final List<Shape> kShapes = <Shape>[
  _shape(0, 'dot', ['#']),

  _shape(1, 'duo-h', ['##']),
  _shape(2, 'duo-v', ['#', '#']),
  _shape(3, 'tri-h', ['###']),
  _shape(4, 'tri-v', ['#', '#', '#']),
  _shape(5, 'quad-h', ['####']),
  _shape(6, 'quad-v', ['#', '#', '#', '#']),
  _shape(7, 'penta-h', ['#####']),
  _shape(8, 'penta-v', ['#', '#', '#', '#', '#']),

  _shape(9, 'square2', ['##', '##']),
  _shape(10, 'square3', ['###', '###', '###']),
  _shape(11, 'rect-2x3', ['##', '##', '##']),
  _shape(12, 'rect-3x2', ['###', '###']),

  // 2x2 corners
  _shape(13, 'corner-tl', ['##', '#.']),
  _shape(14, 'corner-tr', ['##', '.#']),
  _shape(15, 'corner-bl', ['#.', '##']),
  _shape(16, 'corner-br', ['.#', '##']),

  // 3x3 corners (5 cells)
  _shape(17, 'big-corner-tl', ['###', '#..', '#..']),
  _shape(18, 'big-corner-tr', ['###', '..#', '..#']),
  _shape(19, 'big-corner-bl', ['#..', '#..', '###']),
  _shape(20, 'big-corner-br', ['..#', '..#', '###']),

  // J / L, 2 wide by 3 tall
  _shape(21, 'j-a', ['#.', '#.', '##']),
  _shape(22, 'j-b', ['.#', '.#', '##']),
  _shape(23, 'j-c', ['##', '#.', '#.']),
  _shape(24, 'j-d', ['##', '.#', '.#']),

  // J / L, 3 wide by 2 tall
  _shape(25, 'l-a', ['#..', '###']),
  _shape(26, 'l-b', ['###', '#..']),
  _shape(27, 'l-c', ['..#', '###']),
  _shape(28, 'l-d', ['###', '..#']),

  // T
  _shape(29, 't-down', ['###', '.#.']),
  _shape(30, 't-up', ['.#.', '###']),
  _shape(31, 't-right', ['#.', '##', '#.']),
  _shape(32, 't-left', ['.#', '##', '.#']),

  // S / Z
  _shape(33, 's-h', ['.##', '##.']),
  _shape(34, 'z-h', ['##.', '.##']),
  _shape(35, 's-v', ['#.', '##', '.#']),
  _shape(36, 'z-v', ['.#', '##', '#.']),

  // Diagonals
  _shape(37, 'diag2-a', ['#.', '.#']),
  _shape(38, 'diag2-b', ['.#', '#.']),
  _shape(39, 'diag3-a', ['#..', '.#.', '..#']),
  _shape(40, 'diag3-b', ['..#', '.#.', '#..']),
];

/// A concrete piece sitting in a tray slot.
class Piece {
  final int shapeIndex;
  final int colorIndex;

  /// Position in the level's deterministic piece sequence. Also used as a
  /// widget key so a refilled tray animates correctly.
  final int seqIndex;

  const Piece({
    required this.shapeIndex,
    required this.colorIndex,
    required this.seqIndex,
  });

  Shape get shape => kShapes[shapeIndex];

  int get size => shape.size;

  Piece copyWith({int? shapeIndex, int? colorIndex, int? seqIndex}) => Piece(
    shapeIndex: shapeIndex ?? this.shapeIndex,
    colorIndex: colorIndex ?? this.colorIndex,
    seqIndex: seqIndex ?? this.seqIndex,
  );

  @override
  String toString() => 'Piece(${shape.name}, c$colorIndex, #$seqIndex)';
}

/// Deterministic, index addressable piece sequence.
///
/// Index addressable matters: the solver jumps around the sequence without
/// replaying it, and the generator must produce exactly what the device will.
class PieceSequence {
  final int seed;
  final List<int> shapePool;

  const PieceSequence(this.seed, this.shapePool);

  Piece at(int index) {
    final h = _mix(seed, index);
    final shapeIndex = shapePool[(h % shapePool.length).abs()];
    final colorIndex = ((h >> 17) % kPaletteSize).abs();
    return Piece(
      shapeIndex: shapeIndex,
      colorIndex: colorIndex,
      seqIndex: index,
    );
  }

  /// A tray of three, starting at `index`.
  List<Piece?> trayAt(int index) => <Piece?>[
    at(index),
    at(index + 1),
    at(index + 2),
  ];
}

/// SplitMix64-style mixing. Deterministic across platforms for 64-bit ints.
int _mix(int seed, int index) {
  var z = (seed * 0x9E3779B1) ^ (index * 0x85EBCA6B) ^ 0x27D4EB2F;
  z ^= (z >> 33);
  z *= 0xFF51AFD7ED558CCD;
  z ^= (z >> 33);
  z *= 0xC4CEB9FE1A85EC53;
  z ^= (z >> 33);
  return z & 0x3FFFFFFFFFFFFFFF;
}
