import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/audio.dart';
import '../games/games_ids.dart';
import '../games/games_service.dart';
import 'chunky_button.dart';

/// The Play Games / Game Center block on the home screen.
///
/// Two states. Signed out it is a single key that signs in. Signed in it
/// becomes a line naming the player, a tile for each place there is to go -
/// Achievements and Leaderboards - and a quiet Disconnect.
///
/// Disconnect rather than Sign out, because neither platform lets an app sign
/// a player out; see [GamesService.disconnect] for what it does instead.
///
/// It is a [ChunkyButton] like the two above it, so it belongs to the screen
/// rather than sitting on top of it. A flat pill was the correct shape by
/// Google's button spec and the wrong one here: next to two keys with a lit
/// face and a lip it read as a piece of another app.
///
/// What keeps it subordinate to Play and Levels is size and colour, not a
/// different construction: a shorter key with a smaller label, in an almost
/// white that carries a trace of the background's blue so the lip has
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
    if (games.signedIn) return;

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
        if (player == null) return _signIn();
        return _signedIn(player);
      },
    );
  }

  /// Signed out: one key that starts the platform's own sign in sheet.
  Widget _signIn() => Semantics(
    button: true,
    label: 'Sign in with ${GamesIds.serviceName}',
    child: ChunkyButton(
      label: 'Sign in with ${GamesIds.serviceName}',
      leading: _leading(null),
      color: _face,
      // Google's own button spec, and it reads correctly under Apple's too.
      // ChunkyButton drops the label outline for a dark colour on its own.
      labelColor: const Color(0xFF1F1F1F),
      height: 48,
      fontSize: 15,
      onTap: _tap,
    ),
  );

  /// Signed in: who you are, and the two places there are to go.
  ///
  /// Split rather than overloaded. One key that means "sign in", then "who am
  /// I", then "open the leaderboards" is three jobs on one control, and the
  /// third was undiscoverable - nothing about a name says it opens anything.
  /// Achievements had no way in at all, so twenty of them unlocked in silence.
  ///
  /// Each destination only appears when it exists. The same rule the sign in
  /// key already followed: never offer a screen that will not open.
  Widget _signedIn(GamesPlayer player) {
    // Short labels, full names underneath them.
    //
    // "Achievements" and "Leaderboards" do not fit a half-width tile at any
    // size worth reading: on a 320pt phone the tile is 123pt wide and the
    // words need about 144. The icons carry the meaning - a trophy and a bar
    // chart are not ambiguous - and the Semantics label still says the whole
    // thing, so a screen reader announces the real destination.
    final destinations = <Widget>[
      if (GamesIds.achievementsAvailable)
        _destination(
          'Awards',
          'Achievements',
          Icons.emoji_events_rounded,
          () => GamesService.instance.showAchievements(),
        ),
      if (GamesIds.leaderboardAvailable)
        _destination(
          'Ranks',
          'Leaderboards',
          Icons.leaderboard_rounded,
          () => GamesService.instance.showLeaderboard(),
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _identity(player),
        if (destinations.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              for (final destination in destinations) ...[
                if (destination != destinations.first)
                  const SizedBox(width: 10),
                Expanded(child: destination),
              ],
            ],
          ),
        ],
      ],
    );
  }

  /// Who you are, and the one thing that can be done about it.
  ///
  /// The name itself is not a control - there is nothing to do with it - so
  /// the Disconnect sits beside it rather than being hidden behind it.
  Widget _identity(GamesPlayer player) => Semantics(
    label: 'Signed in as ${player.name}',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _leading(player),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: T.dimOnBg,
          ),
        ),
        const SizedBox(width: 6),
        _disconnect(),
      ],
    ),
  );

  /// "Disconnect", not "Sign out".
  ///
  /// The word matters here more than usual. Neither platform lets an app sign
  /// a player out - the account is the device's - so a key labelled Sign out
  /// would leave them signed in to Play Games and looking for the bug. This
  /// does what the game can actually do, and says so.
  ///
  /// Small and quiet, beside the name rather than under the two destinations:
  /// it is the rarest thing on this screen and must not compete with them.
  Widget _disconnect() => Semantics(
    button: true,
    label: 'Disconnect from ${GamesIds.serviceName}',
    child: GestureDetector(
      onTap: _confirmDisconnect,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // Padding rather than a size: the label is 12pt, and a bare 12pt tap
        // target is below every guideline there is.
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          'Disconnect',
          style: T.dimOnBg.copyWith(
            fontSize: 12,
            decoration: TextDecoration.underline,
            decorationColor: textOnBgDim,
          ),
        ),
      ),
    ),
  );

  /// Asked before it happens, because it is not obvious what it costs.
  ///
  /// Nothing is deleted either way - the snapshot stays in the account and the
  /// save stays on the phone - but a player who disconnects stops syncing, and
  /// finding that out afterwards is how progress gets lost on the *next*
  /// device. The sheet says the part that matters and nothing else.
  Future<void> _confirmDisconnect() async {
    AudioService.instance.play(Sfx.tap, volume: 0.6);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: boardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
        title: const Text('Disconnect?', style: T.title),
        content: Text(
          'Progress stops syncing to ${GamesIds.serviceName} on this device. '
          'Nothing is deleted, and connecting again brings it back.',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: T.label),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Disconnect',
              style: T.label.copyWith(color: ghostInvalid),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await GamesService.instance.disconnect();
  }

  /// A tile, side by side, matching the booster and stat tiles above.
  ///
  /// These were full-width stacked keys, because side by side as *keys* they
  /// truncated: ChunkyButton spends 68 logical pixels of every key on padding,
  /// glyph and gap, so at half width "Achievements" and "Leaderboards" both
  /// ellipsed. The height that bought stopped being free once the home screen
  /// filled up - the second key fell 44 pixels below the fold on a 390x844
  /// phone, which is a destination nobody scrolls to find.
  ///
  /// A tile has none of that chrome: the glyph sits above the label rather
  /// than beside it, so the full word fits at half the width. It is also the
  /// shape the rest of this screen already speaks in.
  Widget _destination(
    String label,
    String destination,
    IconData icon,
    VoidCallback onTap,
  ) => Semantics(
    button: true,
    label: destination,
    child: GestureDetector(
      onTap: () {
        AudioService.instance.play(Sfx.tap, volume: 0.6);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: boardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: textAccent),
            const SizedBox(height: 3),
            Text(
              label,
              style: T.label.copyWith(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );

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
