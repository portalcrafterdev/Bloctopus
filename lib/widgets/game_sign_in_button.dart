import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../games/games_ids.dart';
import '../games/games_service.dart';
import 'chunky_button.dart';

/// The sign in pill on the home screen.
///
/// One button, two jobs. Signed out it signs in; signed in it shows who you
/// are and opens the leaderboard. There is no third state and no sign out,
/// because neither platform offers one - see [GamesService].
///
/// It is a [ChunkyButton] like the two above it, so it belongs to the screen
/// rather than sitting on top of it. A flat pill was the correct shape by
/// Google's button spec and the wrong one here: next to two keys with a lit
/// face and a lip it read as a piece of another app.
///
/// What keeps it subordinate to Play and Levels is size and colour, not a
/// different construction: a shorter key with a smaller label, in an almost
/// white that carries a trace of the background's violet so the lip has
/// somewhere to go.
class GameSignInButton extends StatefulWidget {
  const GameSignInButton({super.key});

  @override
  State<GameSignInButton> createState() => _GameSignInButtonState();
}

class _GameSignInButtonState extends State<GameSignInButton> {
  bool _busy = false;

  /// Plain white, and it has to stay plain.
  ///
  /// ChunkyButton derives the lip by dropping this colour's HSL lightness,
  /// which keeps its saturation - and a near white with the faintest tint is
  /// a *highly* saturated colour in HSL terms. An off white that looked white
  /// gave a lip of obvious lilac under a face that read as white, so the two
  /// halves of one key looked like they came from different buttons. At zero
  /// saturation there is no hue left to survive the shift, and the lip comes
  /// out the neutral grey the face wants.
  static const Color _face = Color(0xFFFFFFFF);

  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  Future<void> _tap() async {
    if (_busy) return;
    // No tap sound here: ChunkyButton plays it, and doubling it up on one
    // press is audible as a flam.
    final games = GamesService.instance;

    if (games.signedIn) {
      // Nothing to say when there is no leaderboard yet: the button is still
      // honest about who is signed in, which is the other half of its job.
      if (GamesIds.leaderboardAvailable) await games.showLeaderboard();
      return;
    }

    setState(() => _busy = true);
    final ok = await games.signIn();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) return;

    // One line, no diagnosis. The player cannot act on "project id does not
    // match the signing certificate", and the game does not need them to.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not sign in to ${GamesIds.serviceName} right now.',
          style: T.body.copyWith(color: scrim),
        ),
        backgroundColor: textOnBg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GamesPlayer?>(
      valueListenable: GamesService.instance.player,
      builder: (context, player, _) {
        return Semantics(
          button: true,
          label: player == null
              ? 'Sign in with ${GamesIds.serviceName}'
              : 'Signed in as ${player.name}',
          child: ChunkyButton(
            label: player?.name ?? 'Sign in with ${GamesIds.serviceName}',
            leading: _leading(player),
            // Only once there is somewhere for it to go. Signed in with no
            // leaderboard yet, the button still says who you are, and an icon
            // promising a screen that does not open would be a lie.
            trailing: player != null && GamesIds.leaderboardAvailable
                ? const Icon(
                    Icons.leaderboard_rounded,
                    size: 18,
                    color: Color(0xFF5F6368),
                  )
                : null,
            color: _face,
            // Google's own button spec, and it reads correctly under
            // Apple's too. ChunkyButton drops the label outline for a dark
            // colour on its own.
            labelColor: const Color(0xFF1F1F1F),
            height: 48,
            fontSize: 15,
            onTap: _tap,
          ),
        );
      },
    );
  }

  Widget _leading(GamesPlayer? player) {
    if (_busy) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF5F6368),
        ),
      );
    }
    final icon = player?.icon;
    if (icon != null) {
      return ClipOval(
        child: Image.memory(
          icon,
          width: 22,
          height: 22,
          fit: BoxFit.cover,
          // The avatar comes from the platform already decoded once. If it is
          // somehow unreadable, fall back rather than throwing in build.
          errorBuilder: (_, _, _) => _mark(),
        ),
      );
    }
    return _mark();
  }

  /// Game Center has no logo a third party may draw, so iOS gets a neutral
  /// glyph. Android gets the Google mark, because that is the account the
  /// player is being asked for.
  Widget _mark() => _isIOS
      ? const Icon(
          Icons.sports_esports_rounded,
          size: 20,
          color: Color(0xFF1F1F1F),
        )
      : const SizedBox(
          // A shade larger than the 18 the glyphs use. The mark carries an
          // opening that has to survive at this size, and below 20 it starts
          // to close up and read as a nought.
          width: 20,
          height: 20,
          child: CustomPaint(painter: _GoogleMarkPainter()),
        );
}

/// The Google mark: an open ring in four colours, with the bar coming in from
/// the right.
///
/// The ring is deliberately **not** closed. The sweeps below total 300
/// degrees, not 360, and the missing 60 - from one o'clock round to three -
/// is the whole difference between a G and an O. A closed ring reads as a
/// nought at button size no matter how the colours are arranged.
///
/// Painted rather than shipped so there is no image asset and no licence
/// question in the repo. It is an approximation of a trademark: before
/// release, replace this with the official asset from Google's sign in
/// branding guidelines, which may not be redrawn.
class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _green = Color(0xFF34A853);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _red = Color(0xFFEA4335);

  /// Colour, start angle and sweep, in degrees clockwise from three o'clock.
  ///
  /// Blue starts at three o'clock, where the bar meets it, and the run ends
  /// with red at one o'clock, leaving the opening.
  static const List<(Color, double, double)> _segments =
      <(Color, double, double)>[
        (_blue, 0, 45),
        (_green, 45, 75),
        (_yellow, 120, 75),
        (_red, 195, 105),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    final d = math.min(size.width, size.height);
    final centre = Offset(size.width / 2, size.height / 2);
    // The ring is stroked, so its radius is the middle of the band and the
    // outer edge lands half a stroke beyond it.
    final stroke = d * 0.23;
    final radius = (d - stroke) / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    const rad = math.pi / 180;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    for (final (colour, start, sweep) in _segments) {
      canvas.drawArc(
        rect,
        start * rad,
        sweep * rad,
        false,
        paint..color = colour,
      );
    }

    // The bar, from the middle of the mark out to the ring's outer edge. Its
    // top edge is the top edge of the blue arc where that arc begins, so the
    // two read as one continuous stroke turning the corner rather than as a
    // bar stuck onto a ring.
    canvas.drawRect(
      Rect.fromLTRB(
        centre.dx,
        centre.dy - stroke / 2,
        centre.dx + radius + stroke / 2,
        centre.dy + stroke / 2,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
}
