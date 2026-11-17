import 'package:flutter/material.dart';
import '../services/chess_clock.dart';
import '../theme.dart';

/// Twee klokjes (tegenstander / jij of wit / zwart) naast elkaar.
class ChessClockBar extends StatelessWidget {
  const ChessClockBar({
    super.key,
    required this.leftLabel,
    required this.leftRemaining,
    required this.leftActive,
    required this.leftFlagged,
    this.leftPieceColor = const Color(0xFFF5F0FF),
    required this.rightLabel,
    required this.rightRemaining,
    required this.rightActive,
    required this.rightFlagged,
    this.rightPieceColor = const Color(0xFF14141C),
  });

  final String leftLabel;
  final Duration leftRemaining;
  final bool leftActive;
  final bool leftFlagged;
  final Color leftPieceColor;
  final String rightLabel;
  final Duration rightRemaining;
  final bool rightActive;
  final bool rightFlagged;
  final Color rightPieceColor;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
        _ClockPill(
          label: leftLabel,
          remaining: leftRemaining,
          active: leftActive,
          flagged: leftFlagged,
          pieceColor: leftPieceColor,
        ),
        const SizedBox(width: 10),
        _ClockPill(
          label: rightLabel,
          remaining: rightRemaining,
          active: rightActive,
          flagged: rightFlagged,
          pieceColor: rightPieceColor,
          ),
        ],
      ),
    );
  }
}

class _ClockPill extends StatelessWidget {
  const _ClockPill({
    required this.label,
    required this.remaining,
    required this.active,
    required this.flagged,
    required this.pieceColor,
  });

  final String label;
  final Duration remaining;
  final bool active;
  final bool flagged;
  final Color pieceColor;

  @override
  Widget build(BuildContext context) {
    final critical = active && remaining.inSeconds < 20;
    final Color border = flagged
        ? ChessTheme.red
        : active
            ? ChessTheme.gold
            : ChessTheme.line;
    final Color timeColor = flagged
        ? ChessTheme.red
        : critical
            ? ChessTheme.red
            : (active ? ChessTheme.text : ChessTheme.textDim);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF2A2048) : ChessTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: active ? 2 : 1.5),
        boxShadow: active
            ? [
                BoxShadow(
                  color: ChessTheme.gold.withValues(alpha: 0.25),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pieceColor,
              border: Border.all(color: Colors.black54, width: 1.2),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: ChessTheme.textDim,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                ChessClockSet.format(remaining),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: timeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
