import 'dart:math';

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Blocktopus. Painted in code, never an image asset. See section 9.
enum MascotState { idle, watching, happy, excited, worried, sad, sleeping }

/// Six arms reads cleaner at small sizes than eight. Drop to four if the paint
/// cost ever exceeds 2ms a frame.
const int kArmCount = 6;

/// When the mascot blinks, and how far shut his eyes are right now.
///
/// Pulled out of the widget so the schedule can be tested without a ticker,
/// and so the timing lives in one place instead of being spread through a
/// frame callback. Everything here is measured in monotonic seconds: a clock
/// that wraps cannot be compared against a future time, which is exactly how
/// the blink used to misfire.
@visibleForTesting
class BlinkClock {
  BlinkClock({Random? random}) : _rnd = random ?? Random();

  final Random _rnd;

  /// A blink is a lid travelling down and back up, not a frame of shut eye.
  /// Under 0.12s it reads as a flicker; over 0.3s it reads as a doze.
  static const double closeSeconds = 0.18;

  /// Section 9.2: every 3 to 6 seconds.
  static const double minGap = 3;
  static const double maxGap = 6;

  double _nextAt = minGap;
  double _start = -1;

  bool get isBlinking => _start >= 0;

  /// Call once a frame with the time since the mascot appeared.
  void update(double seconds) {
    if (_start < 0) {
      if (seconds >= _nextAt) _start = seconds;
    } else if (seconds - _start >= closeSeconds) {
      _start = -1;
      _nextAt = seconds + minGap + _rnd.nextDouble() * (maxGap - minGap);
    }
  }

  /// 0 is wide open, 1 is fully shut.
  double amount(double seconds) {
    if (_start < 0) return 0;
    final p = ((seconds - _start) / closeSeconds).clamp(0.0, 1.0);
    // Shuts faster than it opens, which is what an eye actually does. A
    // symmetric blink looks mechanical.
    return p <= 0.4 ? p / 0.4 : 1 - (p - 0.4) / 0.6;
  }
}

class MascotView extends StatefulWidget {
  final double size;
  final MascotState state;

  /// Where the eyes should look, in this widget's local coordinates. Null
  /// means look straight ahead.
  final Offset? lookAt;

  final Color tint;

  const MascotView({
    super.key,
    required this.size,
    this.state = MascotState.idle,
    this.lookAt,
    this.tint = inkPurple,
  });

  @override
  State<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends State<MascotView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  final BlinkClock _blink = BlinkClock();

  /// Seconds since this mascot appeared, and the only clock anything here
  /// reads.
  ///
  /// Accumulated from frame deltas rather than taken from the controller's
  /// value, because the controller wraps every 10 seconds and everything the
  /// mascot does is either a sine of the time or a comparison against a future
  /// time. A wrapping clock breaks both: the arm waves and the body bob
  /// snapped at each wrap, and a blink scheduled just past one fired on the
  /// very next frame instead of seconds later, so he stuttered his eyes
  /// instead of blinking.
  double _seconds = 0;
  double _lastRaw = 0;

  /// Reaction animations run once and settle.
  double _reactionStart = -1;
  MascotState _lastState = MascotState.idle;

  double get _t => _seconds;

  @override
  void initState() {
    super.initState();
    _lastRaw = _clock.value * 10;
    _clock.addListener(_onTick);
  }

  void _onTick() {
    final raw = _clock.value * 10;
    var delta = raw - _lastRaw;
    if (delta < 0) delta += 10; // the controller looped
    _lastRaw = raw;
    _seconds += delta;
    _blink.update(_seconds);
  }

  @override
  void didUpdateWidget(MascotView old) {
    super.didUpdateWidget(old);
    if (widget.state != _lastState) {
      _lastState = widget.state;
      if (widget.state == MascotState.happy ||
          widget.state == MascotState.excited) {
        _reactionStart = _t;
      }
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          var reaction = 0.0;
          if (_reactionStart >= 0) {
            // No wrap to compensate for any more: the clock only moves
            // forwards.
            final elapsed = _t - _reactionStart;
            final duration = widget.state == MascotState.excited ? 0.9 : 0.5;
            reaction = elapsed >= duration ? 0 : 1 - elapsed / duration;
          }
          return CustomPaint(
            painter: _MascotPainter(
              t: _t,
              state: widget.state,
              lookAt: widget.lookAt,
              blink: _blink.amount(_t),
              reaction: reaction,
              tint: widget.tint,
            ),
          );
        },
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final double t;
  final MascotState state;
  final Offset? lookAt;

  /// 0 wide open, 1 fully shut. A fraction, not a flag: an eye that snaps
  /// between open and shut for a few frames reads as a glitch, not a blink.
  final double blink;
  final double reaction; // 1 at the start of a reaction, 0 once settled
  final Color tint;

  _MascotPainter({
    required this.t,
    required this.state,
    required this.lookAt,
    required this.blink,
    required this.reaction,
    required this.tint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    // Nothing to draw, and drawing it anyway throws: at zero size every arm
    // curve collapses to a point, and a zero length path has no metrics for
    // the suckers to be positioned along. A mascot can legitimately be laid
    // out at zero - inside a collapsed box, mid transition, or when a parent
    // sizes him from a value that has not arrived yet - and that must not take
    // the whole frame down with it.
    if (s <= 0) return;
    final centre = Offset(size.width / 2, size.height * 0.42);

    // Body bob, plus the hop on a reaction.
    final bob = sin(t * 1.6) * s * 0.012;
    final hop = state == MascotState.happy || state == MascotState.excited
        ? -sin(reaction * pi) * s * 0.10
        : 0.0;
    final sleepBob = state == MascotState.sleeping
        ? sin(t * 0.9) * s * 0.02
        : 0;
    final droop = state == MascotState.sad ? s * 0.04 : 0.0;

    canvas.save();
    canvas.translate(0, bob + hop + sleepBob + droop);

    if (state == MascotState.excited) {
      // Spin, but only while the reaction is running.
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(sin(reaction * pi * 2) * 0.35);
      canvas.translate(-centre.dx, -centre.dy);
    }

    _paintArms(canvas, size, centre, s);
    _paintHead(canvas, centre, s);
    _paintFace(canvas, centre, s);

    canvas.restore();
  }

  // -- head -----------------------------------------------------------------

  void _paintHead(Canvas canvas, Offset centre, double s) {
    // Roughly 1.15 wide to 1.0 tall.
    final w = s * 0.62;
    final h = w / 1.15;
    final rect = Rect.fromCenter(center: centre, width: w, height: h * 1.18);

    final body = Paint()..color = tint;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(w * 0.5),
        topRight: Radius.circular(w * 0.5),
        bottomLeft: Radius.circular(w * 0.38),
        bottomRight: Radius.circular(w * 0.38),
      ),
      body,
    );

    // Highlight on the upper third.
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(w * 0.5),
        topRight: Radius.circular(w * 0.5),
        bottomLeft: Radius.circular(w * 0.38),
        bottomRight: Radius.circular(w * 0.38),
      ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centre.dx, rect.top + rect.height * 0.16),
        width: w * 0.92,
        height: rect.height * 0.52,
      ),
      Paint()..color = inkPurpleHi.withValues(alpha: 0.55),
    );
    canvas.restore();
  }

  // -- face -----------------------------------------------------------------

  void _paintFace(Canvas canvas, Offset centre, double s) {
    final eyeR = s * 0.072;
    final gap = s * 0.115;
    final eyeY = centre.dy - s * 0.03;
    final left = Offset(centre.dx - gap, eyeY);
    final right = Offset(centre.dx + gap, eyeY);

    // Cheeks.
    final cheek = Paint()..color = inkPink.withValues(alpha: 0.4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centre.dx - gap * 1.55, eyeY + eyeR * 1.5),
        width: s * 0.09,
        height: s * 0.055,
      ),
      cheek,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centre.dx + gap * 1.55, eyeY + eyeR * 1.5),
        width: s * 0.09,
        height: s * 0.055,
      ),
      cheek,
    );

    if (state == MascotState.excited && reaction > 0) {
      _paintStarEye(canvas, left, eyeR * 1.15);
      _paintStarEye(canvas, right, eyeR * 1.15);
      _paintMouth(canvas, centre, s, open: true);
      return;
    }

    // Sleeping is simply a blink that never opens again.
    final shut = state == MascotState.sleeping ? 1.0 : blink;
    final open = 1 - shut;
    final wide = state == MascotState.worried;
    final rx = eyeR * (wide ? 1.2 : 1);
    final ry = eyeR * (wide ? 1.25 : 1);

    if (open <= 0.12) {
      final lid = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2A2148);
      for (final e in <Offset>[left, right]) {
        canvas.drawArc(
          Rect.fromCenter(center: e, width: rx * 2, height: ry * 1.4),
          0.15 * pi,
          0.7 * pi,
          false,
          lid,
        );
      }
    } else {
      // The lid comes down from the top: the bottom of the eye stays where it
      // is and the opening shrinks upward from it. Scaling the whole oval
      // about its centre would read as the eye shrinking rather than closing.
      Rect socket(Offset e) => Rect.fromLTWH(
        e.dx - rx,
        e.dy + ry - ry * 2 * open,
        rx * 2,
        ry * 2 * open,
      );

      final white = Paint()..color = Colors.white;
      canvas.drawOval(socket(left), white);
      canvas.drawOval(socket(right), white);

      // Pupils track the dragged piece. This one detail carries the character.
      final pupil = Paint()..color = const Color(0xFF241C42);
      final pr = eyeR * 0.46;
      // Only mid blink, and only then: clipping every frame would cost two
      // saveLayers a mascot for the 99% of frames where the eye is wide open
      // and nothing is being cut off.
      final lidCovers = open < 0.999;
      for (final e in <Offset>[left, right]) {
        var d = Offset.zero;
        if (lookAt != null) {
          final v = lookAt! - e;
          final len = v.distance;
          if (len > 0.001) {
            final max = eyeR * 0.44;
            d = v / len * min(max, len * 0.16);
          }
        }
        if (lidCovers) {
          canvas.save();
          canvas.clipPath(Path()..addOval(socket(e)));
        }
        canvas.drawCircle(e + d, pr, pupil);
        canvas.drawCircle(
          e + d + Offset(-pr * 0.35, -pr * 0.35),
          pr * 0.32,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
        if (lidCovers) canvas.restore();
      }
    }

    if (state == MascotState.sad) {
      _paintMouth(canvas, centre, s, sad: true);
    } else if (state == MascotState.worried) {
      _paintMouth(canvas, centre, s, flat: true);
    } else if (state == MascotState.sleeping) {
      _paintBubble(canvas, centre, s);
    } else {
      _paintMouth(canvas, centre, s);
    }
  }

  void _paintStarEye(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final p = Offset(c.dx + cos(a) * rr, c.dy + sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = textAccent);
  }

  void _paintMouth(
    Canvas canvas,
    Offset centre,
    double s, {
    bool sad = false,
    bool flat = false,
    bool open = false,
  }) {
    final y = centre.dy + s * 0.075;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.016
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3B2F63);

    if (open) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(centre.dx, y),
          width: s * 0.07,
          height: s * 0.06,
        ),
        Paint()..color = const Color(0xFF3B2F63),
      );
      return;
    }
    if (flat) {
      canvas.drawLine(
        Offset(centre.dx - s * 0.035, y),
        Offset(centre.dx + s * 0.035, y),
        p,
      );
      return;
    }
    final rect = Rect.fromCenter(
      center: Offset(centre.dx, sad ? y + s * 0.02 : y),
      width: s * 0.085,
      height: s * 0.05,
    );
    canvas.drawArc(rect, sad ? pi : 0, pi, false, p);
  }

  void _paintBubble(Canvas canvas, Offset centre, double s) {
    final phase = (t % 3) / 3;
    final r = s * 0.028 * (0.6 + phase);
    canvas.drawCircle(
      Offset(centre.dx + s * 0.19, centre.dy - s * 0.12 - phase * s * 0.16),
      r,
      Paint()..color = Colors.white.withValues(alpha: (1 - phase) * 0.5),
    );
  }

  // -- arms -----------------------------------------------------------------

  void _paintArms(Canvas canvas, Size size, Offset centre, double s) {
    final baseY = centre.dy + s * 0.20;
    final spread = s * 0.30;
    final still = state == MascotState.watching;
    final up = state == MascotState.excited && reaction > 0;
    final pulledIn = state == MascotState.worried;
    final droop = state == MascotState.sad;

    for (var i = 0; i < kArmCount; i++) {
      final f = kArmCount == 1 ? 0.5 : i / (kArmCount - 1);
      final x = centre.dx + (f - 0.5) * 2 * spread;

      // One arm raises on happy.
      final raised = (state == MascotState.happy && i == kArmCount - 1) || up;

      final wave = still ? 0.0 : sin(t * 2.2 + i * 0.9) * s * 0.045;
      final length =
          s * (pulledIn ? 0.16 : 0.26) * (0.85 + (i.isEven ? 0.15 : 0));

      final start = Offset(x, baseY);
      var tipY = baseY + length;
      var ctrlX = x + wave;
      var ctrlY = baseY + length * 0.55;

      if (raised) {
        tipY = baseY - length * 0.55;
        ctrlY = baseY - length * 0.1;
        ctrlX = x + (f - 0.5) * s * 0.22;
      } else if (droop) {
        tipY = baseY + length * 1.15;
        ctrlX = x + (f - 0.5) * s * 0.06;
      }

      final tip = Offset(x + wave * 1.6, tipY);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(ctrlX, ctrlY, tip.dx, tip.dy);

      // Taper: stroke the same curve twice, thinner and shorter.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.055
          ..color = tint,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.030
          ..color = tint,
      );

      // Three suckers down each arm.
      final metric = path.computeMetrics().first;
      for (var k = 1; k <= 3; k++) {
        final pos = metric.getTangentForOffset(metric.length * (k / 3.6));
        if (pos == null) continue;
        canvas.drawCircle(
          pos.position,
          s * 0.011,
          Paint()..color = inkPink.withValues(alpha: 0.85),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MascotPainter old) => true;
}

/// A speech bubble carrying one instruction. At most 12 words, sentence case,
/// no exclamation marks. See section 9.4.
class MascotBubble extends StatelessWidget {
  final String text;

  const MascotBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: boardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: chipBorder),
      ),
      child: Text(text, style: T.body.copyWith(color: textPrimary)),
    );
  }
}
