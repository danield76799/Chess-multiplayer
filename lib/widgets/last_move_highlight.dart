import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;

/// Tekent een zachte goudkleurige gloed op het "van"- en "naar"-veld
/// van de laatste zet, zodat je in één oogopslag ziet wat er net gebeurde.
class LastMoveHighlight extends StatelessWidget {
  const LastMoveHighlight({
    super.key,
    required this.from,
    required this.to,
    required this.orientation,
  });

  /// Veld-notatie, bijv. 'e2'.
  final String from;
  final String to;
  final PlayerColor orientation;

  static const _files = 'abcdefgh';

  static Offset _squareOffset(String square, double squareSize, PlayerColor orientation) {
    final file = _files.indexOf(square[0]);
    final rank = int.tryParse(square.substring(1)) ?? 1;
    final white = orientation == PlayerColor.white;
    final col = white ? file : 7 - file;
    final rowFromTop = white ? 8 - rank : rank - 1;
    return Offset(col * squareSize, rowFromTop * squareSize);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _HighlightPainter(
          from: from,
          to: to,
          orientation: orientation,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  _HighlightPainter({
    required this.from,
    required this.to,
    required this.orientation,
  });

  final String from;
  final String to;
  final PlayerColor orientation;

  @override
  void paint(Canvas canvas, Size size) {
    final sq = size.width / 8;
    final paint = Paint()
      ..color = const Color(0x66FFC53D) // goud, zacht
      ..style = PaintingStyle.fill;
    for (final square in [from, to]) {
      if (square.length < 2) continue;
      final offset = LastMoveHighlight._squareOffset(square, sq, orientation);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          offset.dx + 2,
          offset.dy + 2,
          sq - 4,
          sq - 4,
        ),
        Radius.circular(sq * 0.16),
      );
      canvas.drawRRect(r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.orientation != orientation;
}
