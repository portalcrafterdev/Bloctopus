import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/audio.dart';
import '../models/level.dart';
import '../models/save_data.dart';
import '../widgets/mascot_view.dart';
import '../widgets/menu_button.dart';

enum ResultAction { next, retry, map }

/// The win/lose sheet. Slides up over the board so the final state stays
/// visible behind it.
Future<ResultAction?> showResultSheet(
  BuildContext context, {
  required Level level,
  required LevelResult result,
  required SaveData save,
}) {
  return showModalBottomSheet<ResultAction>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: scrim.withValues(alpha: 0.7),
    builder: (_) => ResultSheet(level: level, result: result, save: save),
  );
}

class ResultSheet extends StatefulWidget {
  final Level level;
  final LevelResult result;
  final SaveData save;

  const ResultSheet({
    super.key,
    required this.level,
    required this.result,
    required this.save,
  });

  @override
  State<ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<ResultSheet> {
  int _starsShown = 0;

  @override
  void initState() {
    super.initState();
    if (widget.result.won) _revealStars();
  }

  Future<void> _revealStars() async {
    for (var i = 1; i <= widget.result.stars; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() => _starsShown = i);
      AudioService.instance.play(Sfx.star, volume: 0.9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final won = widget.result.won;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      decoration: BoxDecoration(
        color: boardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: border),
      ),
      child: SafeArea(
        top: false,
        // The sheet is as tall as its content, and its content grows with a
        // booster award and the replay link. On a short screen that is taller
        // than the sheet is allowed to be, so it scrolls rather than overflows.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: chipBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              MascotView(
                size: 96,
                state: won ? MascotState.excited : MascotState.sad,
              ),
              const SizedBox(height: 10),
              Text(
                won ? 'Level ${widget.level.id} complete' : 'Out of options',
                style: T.title,
              ),
              const SizedBox(height: 6),
              Text(
                won
                    ? _wonSubtitle()
                    : 'Nothing left to place. Try a different order.',
                style: T.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              if (won) _stars(),
              const SizedBox(height: 18),
              _statRow(),
              if (widget.result.boosterAwarded != null) ...[
                const SizedBox(height: 14),
                _boosterAward(widget.result.boosterAwarded!),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: MenuButton(
                      label: 'Map',
                      onTap: () => Navigator.of(context).pop(ResultAction.map),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MenuButton(
                      label: won ? 'Next level' : 'Try again',
                      filled: true,
                      onTap: () => Navigator.of(
                        context,
                      ).pop(won ? ResultAction.next : ResultAction.retry),
                    ),
                  ),
                ],
              ),
              if (won) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(ResultAction.retry),
                  child: const Text('Replay for a better score', style: T.dim),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _wonSubtitle() {
    final t = widget.level.starTargets;
    if (widget.result.stars >= 3) return 'A clean run. Nothing wasted.';
    final needed = widget.result.stars == 1 ? t[1] : t[2];
    return 'Score $needed to earn the next star.';
  }

  Widget _stars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(3, (i) {
        final earned = i < _starsShown;
        return AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          scale: earned ? 1 : 0.72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              earned ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 46,
              color: earned ? textAccent : chipBorder,
            ),
          ),
        );
      }),
    );
  }

  Widget _statRow() {
    // Even thirds rather than spaceEvenly: a six figure score is much wider
    // than a two digit move count, and an intrinsic row lets it push the
    // others off the edge of a narrow screen.
    return Row(
      children: [
        Expanded(child: _stat('Score', '${widget.result.score}')),
        Expanded(child: _stat('Lines', '${widget.result.linesCleared}')),
        Expanded(child: _stat('Moves', '${widget.result.movesUsed}')),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        // Shrinks the number instead of overflowing its third.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: T.heading),
        ),
        const SizedBox(height: 2),
        Text(label, style: T.dim, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _boosterAward(String id) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        // Inset on the dark sheet, so it darkens rather than going light.
        color: scrim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add, size: 16, color: textAccent),
          const SizedBox(width: 8),
          // Flexible, not bare: the row sizes to its content, so on a narrow
          // sheet the label would otherwise carry the whole row past the edge.
          Flexible(
            child: Text(
              'One ${BoosterId.label(id).toLowerCase()} added',
              style: T.label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
