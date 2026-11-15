import 'package:chess/chess.dart' as chess_lib;

/// Berekening van geslagen stukken op basis van de zetgeschiedenis.
class CapturedPieces {
  /// Stukken die WIT geslagen heeft (dus zwarte stukken), op waarde gesorteerd.
  final List<chess_lib.PieceType> byWhite;

  /// Stukken die ZWART geslagen heeft (dus witte stukken), op waarde gesorteerd.
  final List<chess_lib.PieceType> byBlack;

  const CapturedPieces(this.byWhite, this.byBlack);

  static const Map<String, int> values = {
    'p': 1,
    'n': 3,
    'b': 3,
    'r': 5,
    'q': 9,
    'k': 0,
  };

  static int valueOf(chess_lib.PieceType type) => values[type.name] ?? 0;

  int get whiteScore =>
      byWhite.fold(0, (sum, piece) => sum + valueOf(piece));
  int get blackScore =>
      byBlack.fold(0, (sum, piece) => sum + valueOf(piece));

  /// Positief = wit staat materiaal voor, negatief = zwart.
  int get materialDiff => whiteScore - blackScore;

  bool get isEmpty => byWhite.isEmpty && byBlack.isEmpty;
}

CapturedPieces capturedPieces(chess_lib.Chess game) {
  final byWhite = <chess_lib.PieceType>[];
  final byBlack = <chess_lib.PieceType>[];
  for (final state in game.history) {
    final captured = state.move.captured;
    if (captured == null) continue;
    if (state.move.color == chess_lib.Chess.WHITE) {
      byWhite.add(captured);
    } else {
      byBlack.add(captured);
    }
  }
  byWhite.sort((a, b) => CapturedPieces.valueOf(b).compareTo(CapturedPieces.valueOf(a)));
  byBlack.sort((a, b) => CapturedPieces.valueOf(b).compareTo(CapturedPieces.valueOf(a)));
  return CapturedPieces(byWhite, byBlack);
}
