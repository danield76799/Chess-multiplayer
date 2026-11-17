import 'package:flutter/material.dart';
import '../services/chess_clock.dart';
import '../theme.dart';

/// Keuze voor de bedenktijd (toernooi-klok), gedeeld door de
/// singleplayer- en multiplayer-flow.
class TimeControlPicker extends StatelessWidget {
  const TimeControlPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TimeControl selected;
  final ValueChanged<TimeControl> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bedenktijd',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ChessTheme.textDim,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final tc in TimeControl.presets)
              ChoiceChip(
                label: Text('⏱ ${tc.label}'),
                selected: tc.base == selected.base &&
                    tc.increment == selected.increment,
                onSelected: (_) => onChanged(tc),
              ),
          ],
        ),
      ],
    );
  }
}
