import 'package:chess/chess.dart' as chess_lib;

import 'chess_ai.dart';

/// Eén zet in de partij-analyse.
class MoveReview {
  const MoveReview({
    required this.moveNumber,
    required this.san,
    required this.lossCp,
    required this.bestSan,
    required this.byWhite,
  });

  /// Volledige zetnummering, zoals op notatie-bladen (1, 1, 2, 2, …).
  final int moveNumber;
  final String san;

  /// Verlies in centipions ten opzichte van de beste speelbare stelling
  /// (0 = net zo goed gespeeld).
  final int lossCp;

  /// Beste zet volgens de ingebouwde AI, voor de "beter was …"-hint.
  final String? bestSan;
  final bool byWhite;
}

/// Resultaat van een partij-analyse voor één kleur.
class GameReview {
  const GameReview({
    required this.reviewWhite,
    required this.moves,
    required this.inaccuracies,
    required this.mistakes,
    required this.blunders,
    this.worst,
  });

  /// true = wit is geanalyseerd, false = zwart.
  final bool reviewWhite;
  final List<MoveReview> moves;
  final int inaccuracies;
  final int mistakes;
  final int blunders;

  /// De zet met het grootste gemeten verlies (of null bij een foutloze partij).
  final MoveReview? worst;

  bool get clean => blunders == 0 && mistakes == 0 && inaccuracies == 0;
}

/// Analyseert een gespeelde partij met de ingebouwde AI.
///
/// De analyse is bewust lichtgewicht: per zet van de bekeken kant rekenen we
/// de stelling-evaluatie vóór en na de beste antwoordzet van de tegenstander.
/// Het verschil is wat die zet gekost heeft. Dit is geen engine-perfecte
/// analyse, maar voor een kinder-/familiekamer-app ruim genoeg om de grote
/// blunders te vinden ("je dame stond en prise").
class GameReviewService {
  static const int inaccuracyCp = 60;
  static const int mistakeCp = 120;
  static const int blunderCp = 250;
  static const int _mateValue = 100000;

  static int _rel(int whitePovEval, bool whiteToMove) =>
      whiteToMove ? whitePovEval : -whitePovEval;

  /// Analyseert de partijen vanuit het perspectief van [reviewWhite].
  /// [sanMoves] is de volledige zettenlijst in SAN, in volgorde.
  static GameReview analyze(List<String> sanMoves, {required bool reviewWhite}) {
    final pos = chess_lib.Chess();
    final reviewed = <MoveReview>[];
    var inaccuracies = 0, mistakes = 0, blunders = 0;
    MoveReview? worst;

    var fullMove = 1;
    for (final san in sanMoves) {
      if (pos.game_over) break;
      final whiteToMove = pos.turn == chess_lib.Chess.WHITE;
      final isReviewed = whiteToMove == reviewWhite;

      final evalBefore = _rel(ChessAI.evaluate(pos), whiteToMove);
      final bestMove = ChessAI.pickMove(pos, difficulty: AIDifficulty.normaal);
      final bestSan = bestMove == null ? null : pos.move_to_san(bestMove);

      final ok = pos.move(san);
      if (!ok) break;

      int loss = 0;
      if (pos.game_over) {
        // Mijn zet maakte mat (of patt): nietes te betreuren.
        loss = 0;
      } else {
        // Beste antwoord van de tegenstander.
        final reply = ChessAI.pickMove(pos, difficulty: AIDifficulty.normaal);
        if (reply == null) {
          loss = 0; // mag niet voorkomen (niet mat/pat na pos.move), defensief.
        } else {
          pos.make_move(reply);
          if (pos.game_over && pos.in_check) {
            // Ik werd mat gezet na mijn zet: dat is de doodste blunder.
            loss = _mateValue;
          } else if (pos.game_over) {
            loss = 0; // patt na mijn zet: niet afstraffen
          } else {
            final evalAfter = _rel(ChessAI.evaluate(pos), whiteToMove);
            loss = evalBefore - evalAfter;
            if (loss < 0) loss = 0;
          }
          pos.undo_move();
        }
      }

      if (isReviewed) {
        if (loss >= blunderCp) blunders++;
        if (loss >= mistakeCp) mistakes++;
        if (loss >= inaccuracyCp) inaccuracies++;
        final review = MoveReview(
          moveNumber: fullMove,
          san: san,
          lossCp: loss,
          bestSan: bestSan,
          byWhite: whiteToMove,
        );
        reviewed.add(review);
        if (worst == null || review.lossCp > worst.lossCp) {
          worst = review;
        }
      }

      if (!whiteToMove) fullMove++;
    }

    return GameReview(
      reviewWhite: reviewWhite,
      moves: reviewed,
      inaccuracies: inaccuracies,
      mistakes: mistakes,
      blunders: blunders,
      worst: worst != null && worst.lossCp >= inaccuracyCp ? worst : null,
    );
  }
}
