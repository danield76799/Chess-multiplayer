import 'dart:math';
import 'package:chess/chess.dart' as chess_lib;

/// Een eenvoudige maar speelbare schaak-AI voor singleplayer.
///
/// Implementatie: minimax met alpha-beta snoeiing en MVV-LVA ordening
/// van zetten, op een evaluatie van materiaal plus stuk-vierkant-tabellen
/// (from White's perspectief; zwart wordt gespiegeld).
///
/// Moeilijkheid bepaalt de zoekdiepte:
/// - [AIDifficulty.makkelijk] = diepte 1 + af en toe een willekeurige zet
/// - [AIDifficulty.normaal]   = diepte 2
/// - [AIDifficulty.moeilijk]  = diepte 3
enum AIDifficulty { makkelijk, normaal, moeilijk }

class ChessAI {
  static const int _mateScore = 100000;

  static const Map<String, int> _values = {
    'p': 100,
    'n': 320,
    'b': 330,
    'r': 500,
    'q': 900,
    'k': 0,
  };

  // Piece-square tabellen, index 0 = a8 … 63 = h1 (White's perspectief).
  static const List<int> _pawn = [
    0, 0, 0, 0, 0, 0, 0, 0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
  ];
  static const List<int> _knight = [
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
  ];
  static const List<int> _bishop = [
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
  ];
  static const List<int> _rook = [
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, 10, 10, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, 10, 10, 10, 10, 5,
    0, 0, 0, 5, 5, 0, 0, 0,
  ];
  static const List<int> _queen = [
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -5, 0, 5, 5, 5, 5, 0, -5,
    0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 5, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
  ];
  static const List<int> _king = [
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    20, 30, 0, 0, 0, 0, 30, 20,
    20, 30, 10, 0, 0, 10, 30, 20,
  ];

  static List<int> _tableFor(String pieceType) {
    switch (pieceType) {
      case 'p':
        return _pawn;
      case 'n':
        return _knight;
      case 'b':
        return _bishop;
      case 'r':
        return _rook;
      case 'q':
        return _queen;
      default:
        return _king;
    }
  }

  /// Statische evaluatie in centipunten, positief = wit staat beter.
  static int evaluate(chess_lib.Chess game) {
    int score = 0;
    final board = game.board;
    const kings = {chess_lib.Chess.WHITE, chess_lib.Chess.BLACK};
    for (var sq = 0; sq < 128; sq++) {
      if ((sq & 0x88) != 0) continue;
      final piece = board[sq];
      if (piece == null) continue;
      final rankFromTop = (sq & 0x70) >> 4; // 0 = 8e rij … 7 = 1e rij
      final file = sq & 7;
      final isWhite = piece.color == chess_lib.Chess.WHITE;
      // Wit leest de tabel van boven (0 = a8), zwart gespiegeld.
      final idx = isWhite ? rankFromTop * 8 + file : (7 - rankFromTop) * 8 + file;
      final value = (_values[piece.type.name] ?? 0) + _tableFor(piece.type.name)[idx];
      score += isWhite ? value : -value;
    }
    assert(kings.length == 2);
    return score;
  }

  static int _sign(chess_lib.Color color) =>
      color == chess_lib.Chess.WHITE ? 1 : -1;

  /// Orden zetten: vangsten (MVV-LVA) en promoties eerst.
  static List<chess_lib.Move> _orderedMoves(chess_lib.Chess game) {
    final moves = List<chess_lib.Move>.from(game.generate_moves());
    int scoreOf(chess_lib.Move m) {
      var s = 0;
      if (m.captured != null) {
        s = 10 * (_values[m.captured!.name] ?? 0) - (_values[m.piece.name] ?? 0) ~/ 10;
      }
      if (m.promotion != null) s += _values[m.promotion!.name] ?? 0;
      return s;
    }

    moves.sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));
    return moves;
  }

  static int _negamax(chess_lib.Chess game, int depth, int alpha, int beta) {
    if (depth == 0) {
      return _sign(game.turn) * evaluate(game);
    }
    final moves = _orderedMoves(game);
    if (moves.isEmpty) {
      // Schaakmat (zij aan zet is verloren) of patt.
      return game.in_check ? -_mateScore - depth : 0;
    }
    var best = -1 << 30;
    for (final move in moves) {
      game.make_move(move);
      final score = -_negamax(game, depth - 1, -beta, -alpha);
      game.undo_move();
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  /// Kies de beste zet voor de kant die aan de beurt is.
  /// Geeft null terug als er geen zetten zijn (mat/pat).
  static chess_lib.Move? pickMove(
    chess_lib.Chess game, {
    AIDifficulty difficulty = AIDifficulty.normaal,
    Random? random,
  }) {
    final rng = random ?? Random();
    final moves = _orderedMoves(game);
    if (moves.isEmpty) return null;

    if (difficulty == AIDifficulty.makkelijk && rng.nextDouble() < 0.3) {
      return moves[rng.nextInt(moves.length)];
    }

    final depth = switch (difficulty) {
      AIDifficulty.makkelijk => 1,
      AIDifficulty.normaal => 2,
      AIDifficulty.moeilijk => 3,
    };

    var bestScore = -1 << 30;
    var bestMoves = <chess_lib.Move>[];
    for (final move in moves) {
      game.make_move(move);
      final raw = -_negamax(game, depth - 1, -(1 << 30), 1 << 30);
      game.undo_move();
      // negamax geeft de score relatief t.o.v. de speler die aan zet is.
      if (raw > bestScore) {
        bestScore = raw;
        bestMoves = [move];
      } else if (raw == bestScore) {
        bestMoves.add(move);
      }
    }
    return bestMoves[rng.nextInt(bestMoves.length)];
  }
}
