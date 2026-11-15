import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;

import 'package:chess_multiplayer/services/chess_ai.dart';

void main() {
  group('ChessAI', () {
    test('begint met een vrijwel gelijke stelling in de openingspositie', () {
      final game = chess_lib.Chess();
      expect(ChessAI.evaluate(game).abs(), lessThanOrEqualTo(30));
    });

    test('geeft een legale eigen zet terug', () {
      final game = chess_lib.Chess();
      final move = ChessAI.pickMove(game, difficulty: AIDifficulty.normaal);
      expect(move, isNotNull);
      final legal = game.generate_moves();
      expect(
        legal.any((m) => m.from == move!.from && m.to == move.to),
        isTrue,
      );
    });

    test('vindt mat in 1 (Scholar’s mate patroon)', () {
      // 1. e4 e5 2. Dh5 Pc6 3. Lc4 Pf6?? 4. Dxf7#
      final game = chess_lib.Chess();
      game.move({'from': 'e2', 'to': 'e4'});
      game.move({'from': 'e7', 'to': 'e5'});
      game.move({'from': 'd1', 'to': 'h5'});
      game.move({'from': 'b8', 'to': 'c6'});
      game.move({'from': 'f1', 'to': 'c4'});
      game.move({'from': 'g8', 'to': 'f6'});
      final move = ChessAI.pickMove(game, difficulty: AIDifficulty.normaal);
      expect(move, isNotNull);
      game.make_move(move!);
      expect(game.in_checkmate, isTrue);
    });

    test('geeft null terug als het spel voorbij is', () {
      final game = chess_lib.Chess();
      // Speel fool's mate: 1. f3 e5 2. g4 Dh4#
      game.move({'from': 'f2', 'to': 'f3'});
      game.move({'from': 'e7', 'to': 'e5'});
      game.move({'from': 'g2', 'to': 'g4'});
      game.move({'from': 'd8', 'to': 'h4'});
      expect(game.game_over, isTrue);
      expect(
        ChessAI.pickMove(game, difficulty: AIDifficulty.makkelijk),
        isNull,
      );
    });

    test('makkelijk-niveau blijft binnen een redelijke tijd', () {
      final game = chess_lib.Chess();
      final stopwatch = Stopwatch()..start();
      ChessAI.pickMove(game, difficulty: AIDifficulty.makkelijk);
      stopwatch.stop();
      // Makkelijk mag nooit langer dan 2 seconden duren.
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });
  });
}
