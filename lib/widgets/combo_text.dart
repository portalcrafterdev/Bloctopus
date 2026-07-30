import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../app/theme.dart';

/// Section 10.3. Text floats up from the board centre: rise 58px over 900ms,
/// opacity 0 to 1 to 0, ease out.
const double kComboRise = 58;
const Duration kComboDuration = Duration(milliseconds: 900);

/// The streak ladder.
///
/// Section 10.3 starts this at streak 3 with `Nice`. `Combo` is prepended at
/// streak 2 on the owner's call: two clears back to back is the moment the
/// player has actually done something worth naming, and leaving it silent
/// meant the most common combo in the game got no callout at all.
const List<String> kStreakWords = <String>[
  'Combo',
  'Nice',
  'Great',
  'Excellent',
  'Unstoppable',
  'Legendary',
];

/// The streak the ladder starts at.
const int kStreakWordFrom = 2;

String? streakWord(int streak) {
  if (streak < kStreakWordFrom) return null;
  final i = (streak - kStreakWordFrom).clamp(0, kStreakWords.length - 1);
  return kStreakWords[i];
}

class _FloatingText {
  final String text;
  final TextStyle style;
  final Offset origin;

  /// Streak words are outlined and pop in; the running score is not. The word
  /// lands on top of a board full of bright blocks and has to stay readable
  /// against any of them, and section 3 caps font weight at 600, so the
  /// presence has to come from a stroke rather than a heavier face.
  final bool emphasis;

  double t = 0; // 0..1

  _FloatingText(this.text, this.style, this.origin, {this.emphasis = false});
}

class ComboTextController extends ChangeNotifier {
  final List<_FloatingText> _items = <_FloatingText>[];
  VoidCallback? onWake;

  bool get isEmpty => _items.isEmpty;

  /// `+{score}` for one line, `{n} lines +{score}` for more.
  void showClear(Offset centre, int lines, int score) {
    final text = lines == 1 ? '+$score' : '$lines lines +$score';
    _items.add(_FloatingText(text, T.combo, centre));
    _wake();
  }

  void showStreak(Offset centre, int streak) {
    final word = streakWord(streak);
    if (word == null) return;
    _items.add(
      _FloatingText(
        word,
        T.combo.copyWith(fontSize: 34),
        centre + const Offset(0, -34),
        emphasis: true,
      ),
    );
    _wake();
  }

  void _wake() {
    onWake?.call();
    notifyListeners();
  }

  void tick(double dt) {
    if (_items.isEmpty) return;
    final step = dt / (kComboDuration.inMilliseconds / 1000);
    for (var i = _items.length - 1; i >= 0; i--) {
      _items[i].t += step;
      if (_items[i].t >= 1) _items.removeAt(i);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}

class ComboTextLayer extends StatefulWidget {
  final ComboTextController controller;

  const ComboTextLayer({super.key, required this.controller});

  @override
  State<ComboTextLayer> createState() => _ComboTextLayerState();
}

class _ComboTextLayerState extends State<ComboTextLayer>
    with SingleTickerProviderStateMixin {
  // Created eagerly: a lazy `late final` would be initialised by dispose()
  // itself, which looks up an ancestor on a deactivated element.
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.controller.onWake = _wake;
  }

  void _wake() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    widget.controller.tick(dt.clamp(0, 0.05));
    if (widget.controller.isEmpty) _ticker.stop();
  }

  @override
  void dispose() {
    widget.controller.onWake = null;
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ComboPainter(widget.controller),
        size: Size.infinite,
      ),
    );
  }
}

class _ComboPainter extends CustomPainter {
  final ComboTextController controller;

  _ComboPainter(this.controller) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in controller._items) {
      final eased = Curves.easeOut.transform(item.t.clamp(0, 1));
      // 0 to 1 to 0.
      final opacity =
          (item.t < 0.18
                  ? item.t / 0.18
                  : (1 - (item.t - 0.18) / 0.82).clamp(0, 1))
              .toDouble();

      final fill = TextPainter(
        text: TextSpan(
          text: item.text,
          style: item.style.copyWith(
            color: item.style.color?.withValues(alpha: opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final centre = Offset(
        item.origin.dx,
        item.origin.dy - kComboRise * eased,
      );
      final topLeft = centre - Offset(fill.width / 2, fill.height / 2);

      canvas.save();
      if (item.emphasis) {
        // A short overshoot on the way in, so the word arrives rather than
        // just appearing. Settled well before the rise finishes.
        final k = (item.t / 0.26).clamp(0.0, 1.0);
        final scale = 0.72 + Curves.easeOutBack.transform(k) * 0.28;
        canvas.translate(centre.dx, centre.dy);
        canvas.scale(scale);
        canvas.translate(-centre.dx, -centre.dy);

        // Built fresh rather than copied: a TextStyle may carry `color` or
        // `foreground`, never both, and copyWith cannot drop the colour.
        final outline = TextPainter(
          text: TextSpan(
            text: item.text,
            style: TextStyle(
              fontSize: item.style.fontSize,
              fontWeight: item.style.fontWeight,
              letterSpacing: item.style.letterSpacing,
              height: item.style.height,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 5
                ..strokeJoin = StrokeJoin.round
                // Dark, whatever the background is doing: this outline exists
                // so amber text stays legible on a yellow or orange block.
                ..color = scrim.withValues(alpha: opacity * 0.9),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        outline.paint(canvas, topLeft);
      }

      fill.paint(canvas, topLeft);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ComboPainter old) => false;
}
