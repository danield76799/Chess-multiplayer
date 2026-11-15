import 'package:chess/chess.dart' as chess_lib;
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';

import '../services/captured_pieces.dart';
import '../theme.dart';

/// Compacte strook onder het bord: welke stukken er geslagen zijn en wie
/// materiaal voorstaat (zoals de "geslagen stukken"-rij naast de klok in
/// online schaakapps).
class CapturedPiecesBar extends StatelessWidget {
  final chess_lib.Chess game;

  const CapturedPiecesBar({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final captured = capturedPieces(game);
    if (captured.isEmpty) return const SizedBox.shrink();

    final diff = captured.materialDiff;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ChessTheme.surfaceHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ChessTheme.line),
      ),
      child: Row(
        children: [
          Expanded(child: _side('Wit', captured.byWhite, chess_lib.Chess.BLACK)),
          Container(width: 1, height: 22, color: ChessTheme.line),
          Expanded(
            child: _side('Zwart', captured.byBlack, chess_lib.Chess.WHITE,
                mirror: true),
          ),
          if (diff != 0) _DiffBadge(diff: diff),
        ],
      ),
    );
  }

  Widget _side(String label, List<chess_lib.PieceType> pieces, chess_lib.Color capturedColor,
      {bool mirror = false}) {
    final icons = pieces
        .map((p) => _pieceIcon(p, capturedColor, 20))
        .toList(growable: false);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ChessTheme.textDim,
          ),
        ),
        const SizedBox(width: 6),
        // Stukken iets overlappend weergeven, zoals bij schaakapps gebruikelijk.
        for (var i = 0; i < icons.length; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
            child: icons[i],
          ),
      ],
    );
    return Align(
      alignment: mirror ? Alignment.centerRight : Alignment.centerLeft,
      child: content,
    );
  }

  Widget _pieceIcon(chess_lib.PieceType type, chess_lib.Color color, double size) {
    final isWhite = color == chess_lib.Chess.WHITE;
    switch (type.name) {
      case 'p':
        return isWhite ? WhitePawn(size: size) : BlackPawn(size: size);
      case 'n':
        return isWhite ? WhiteKnight(size: size) : BlackKnight(size: size);
      case 'b':
        return isWhite ? WhiteBishop(size: size) : BlackBishop(size: size);
      case 'r':
        return isWhite ? WhiteRook(size: size) : BlackRook(size: size);
      case 'q':
        return isWhite ? WhiteQueen(size: size) : BlackQueen(size: size);
      default:
        return isWhite ? WhiteKing(size: size) : BlackKing(size: size);
    }
  }
}

class _DiffBadge extends StatelessWidget {
  final int diff;
  const _DiffBadge({required this.diff});

  @override
  Widget build(BuildContext context) {
    final white = diff > 0;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ChessTheme.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ChessTheme.gold.withValues(alpha: 0.5)),
      ),
      child: Text(
        white ? 'Wit +${diff.abs()}' : 'Zwart +${diff.abs()}',
        style: const TextStyle(
          color: ChessTheme.gold,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
