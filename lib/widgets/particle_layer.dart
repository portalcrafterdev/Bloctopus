import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../app/theme.dart';

/// Section 10.1. One painter for every particle, never one widget per
/// particle. Hard cap of 400 live particles, oldest dropped first.
const int kMaxParticles = 400;

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  int life;
  final int maxLife;
  final double size;
  final Color color;
  final bool bubble;

  /// Shards of a smashed block tumble. Everything else is a 2px square where
  /// rotation would be invisible, so both default to zero and the painter
  /// takes a cheaper path.
  double angle;
  final double spin;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.maxLife,
    required this.size,
    required this.color,
    this.bubble = false,
    this.angle = 0,
    this.spin = 0,
  }) : life = maxLife;
}

/// Holds the live particles. The widget drives it; the game screen feeds it.
class ParticleController extends ChangeNotifier {
  final List<Particle> particles = <Particle>[];
  final Random _rnd = Random();

  /// Halves emission counts when the player has asked for reduced motion.
  bool reduceMotion = false;

  /// Raised when the field goes from empty to non-empty so the host can start
  /// its ticker.
  VoidCallback? onWake;

  bool get isEmpty => particles.isEmpty;

  int _scaled(int n) => reduceMotion ? (n / 2).ceil() : n;

  void _add(Particle p) {
    particles.add(p);
    if (particles.length > kMaxParticles) {
      particles.removeRange(0, particles.length - kMaxParticles);
    }
  }

  /// 6 to 9 particles per cleared cell, in that cell's colour.
  void burstCell(Offset centre, Color color, double cellSize) {
    final n = _scaled(6 + _rnd.nextInt(4));
    for (var i = 0; i < n; i++) {
      final a = _rnd.nextDouble() * pi * 2;
      final speed = 2 + _rnd.nextDouble() * 5;
      _add(
        Particle(
          x: centre.dx,
          y: centre.dy,
          vx: cos(a) * speed,
          vy: sin(a) * speed,
          maxLife: 26 + _rnd.nextInt(9),
          size: 2 + _rnd.nextDouble(),
          color: color,
        ),
      );
    }
    _wake();
  }

  /// Three small particles at the edge of a piece that did not clear anything.
  void puff(Offset centre, Color color) {
    final n = _scaled(3);
    for (var i = 0; i < n; i++) {
      final a = _rnd.nextDouble() * pi * 2;
      _add(
        Particle(
          x: centre.dx,
          y: centre.dy,
          vx: cos(a) * 1.6,
          vy: sin(a) * 1.6 - 0.6,
          maxLife: 18 + _rnd.nextInt(6),
          size: 2,
          color: color,
        ),
      );
    }
    _wake();
  }

  /// A block smashed by Ink Blast: it comes apart into quarters that tumble
  /// away under gravity, plus a spray of chips.
  ///
  /// Deliberately not [burstCell]. A cleared line dissolves, but a hammered
  /// block should look like it broke, and a shower of 2px dust does not read
  /// as breakage. The quarters start where they actually sat inside the cell,
  /// so for the first frame the block still looks whole and then splits.
  void shatterCell(Offset centre, Color color, double cellSize) {
    // Nearly half a cell each, so the four of them together are recognisably
    // the block that was standing there a frame ago.
    final quarter = cellSize * 0.44;
    for (var i = 0; i < 4; i++) {
      final dx = (i.isEven ? -1 : 1) * quarter * 0.5;
      final dy = (i < 2 ? -1 : 1) * quarter * 0.5;
      _add(
        Particle(
          x: centre.dx + dx - quarter / 2,
          y: centre.dy + dy - quarter / 2,
          // Thrown hard, outwards from the point of impact and upwards: the
          // hammer came down, so the pieces have to go somewhere. Drag is 0.92
          // a frame, so a piece travels about 12.5 times its starting speed in
          // total - these clear the cell by two squares or more.
          //
          // The first cut used a third of this and lived half again as long,
          // which left four opaque quarters loitering on the square they came
          // from. That does not read as a block breaking, it reads as a broken
          // block that never left.
          vx: dx * 0.85 + (_rnd.nextDouble() - 0.5) * 2.4,
          vy: dy * 0.4 - 4.2 - _rnd.nextDouble() * 1.4,
          maxLife: 26 + _rnd.nextInt(8),
          size: quarter,
          color: color,
          angle: _rnd.nextDouble() * pi,
          spin: (_rnd.nextDouble() - 0.5) * 0.4,
        ),
      );
    }

    final chips = _scaled(10);
    for (var i = 0; i < chips; i++) {
      final a = _rnd.nextDouble() * pi * 2;
      final speed = 2.5 + _rnd.nextDouble() * 5;
      _add(
        Particle(
          x: centre.dx,
          y: centre.dy,
          vx: cos(a) * speed,
          vy: sin(a) * speed - 1.4,
          // Shorter lived than the quarters above. The dust is the noise of
          // the impact; the pieces are the point, and should be the last thing
          // still on screen.
          maxLife: 18 + _rnd.nextInt(8),
          size: 2 + _rnd.nextDouble() * 2,
          color: color,
        ),
      );
    }
    _wake();
  }

  /// A star being collected: gold, tumbling, and thrown upward hard enough to
  /// read as leaving the board rather than as more debris from the clear it
  /// arrived with.
  void starPop(Offset centre, double cellSize) {
    final flake = cellSize * 0.22;
    for (var i = 0; i < 5; i++) {
      final a = -pi / 2 + (i - 2) * 0.42;
      _add(
        Particle(
          x: centre.dx - flake / 2,
          y: centre.dy - flake / 2,
          vx: cos(a) * 2.4,
          vy: sin(a) * 4.2,
          maxLife: 40 + _rnd.nextInt(10),
          size: flake,
          color: textAccent,
          angle: _rnd.nextDouble() * pi,
          spin: (_rnd.nextDouble() - 0.5) * 0.5,
        ),
      );
    }
    _wake();
  }

  /// Ink bubbles rising from the mascot corner on a big clear.
  void inkBubbles(Offset from) {
    final n = _scaled(8);
    for (var i = 0; i < n; i++) {
      _add(
        Particle(
          x: from.dx + _rnd.nextDouble() * 28 - 14,
          y: from.dy,
          vx: (_rnd.nextDouble() - 0.5) * 0.8,
          vy: -(1.2 + _rnd.nextDouble() * 1.6),
          maxLife: 44 + _rnd.nextInt(18),
          size: 2.5 + _rnd.nextDouble() * 3,
          color: inkPurpleHi,
          bubble: true,
        ),
      );
    }
    _wake();
  }

  void _wake() {
    onWake?.call();
    notifyListeners();
  }

  void tick() {
    if (particles.isEmpty) return;
    for (var i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.x += p.vx;
      p.y += p.vy;
      if (p.bubble) {
        p.vy *= 0.99;
        p.x += sin(p.life * 0.2) * 0.4;
      } else {
        p.vx *= 0.92;
        p.vy *= 0.92;
        p.vy += 0.18; // a little gravity so debris settles
        p.angle += p.spin;
      }
      p.life--;
      if (p.life <= 0) particles.removeAt(i);
    }
    notifyListeners();
  }

  void clear() {
    particles.clear();
    notifyListeners();
  }
}

class ParticleLayer extends StatefulWidget {
  final ParticleController controller;

  const ParticleLayer({super.key, required this.controller});

  @override
  State<ParticleLayer> createState() => _ParticleLayerState();
}

class _ParticleLayerState extends State<ParticleLayer>
    with SingleTickerProviderStateMixin {
  // Created eagerly: a lazy `late final` would be initialised by dispose()
  // itself, which looks up an ancestor on a deactivated element.
  late final Ticker _ticker;

  /// Held so [dispose] can tell this layer's registration apart from a
  /// replacement's. A tear-off is a fresh closure each time it is written.
  late final VoidCallback _wakeRef = _wake;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.controller.onWake = _wakeRef;
    // The field may already be full. This layer's element gets rebuilt
    // whenever the stack around it gains or loses a child, and the particles
    // in flight at that moment belong to the controller, not to the old state.
    if (!widget.controller.isEmpty) _ticker.start();
  }

  void _wake() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration _) {
    widget.controller.tick();
    if (widget.controller.isEmpty) _ticker.stop();
  }

  @override
  void dispose() {
    // Only if it is still ours. When this layer's element is rebuilt at a
    // different index, Flutter inflates the replacement before unmounting this
    // one, so the replacement has already registered by the time we get here.
    // Clearing unconditionally nulled out the live registration, and the field
    // never woke again: particles froze mid-flight and piled up on the board.
    if (identical(widget.controller.onWake, _wakeRef)) {
      widget.controller.onWake = null;
    }
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ParticlePainter(widget.controller),
        size: Size.infinite,
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final ParticleController controller;

  _ParticlePainter(this.controller) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in controller.particles) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      // Dust fades the whole way down, but a shard is a piece of a block and
      // has to look solid while it is tumbling. Fading it from the first frame
      // made a smashed block read as a puff rather than as breakage.
      //
      // It holds full colour only while it is leaving, though, then dissolves
      // over most of the rest. Holding it opaque nearly to the end left the
      // pieces sitting on the board looking like they had never gone.
      final alpha = p.spin == 0 ? t * 0.95 : (t / 0.55).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: alpha);
      if (p.bubble) {
        canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
      } else if (p.spin == 0) {
        // The common case, and the reason the rotation is opt in: hundreds of
        // 2px squares are not worth a save/restore each.
        canvas.drawRect(Rect.fromLTWH(p.x, p.y, p.size, p.size), paint);
      } else {
        final half = p.size / 2;
        canvas.save();
        canvas.translate(p.x + half, p.y + half);
        canvas.rotate(p.angle);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
            Radius.circular(p.size * kCellRadiusFactor),
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => false;
}
