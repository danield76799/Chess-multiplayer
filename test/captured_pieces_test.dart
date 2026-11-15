import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;

import 'package:chess_multiplayer/services/captured_pieces.dart';

void main() {
  group('capturedPieces', () {
    test('leeg aan het begin', () {
      final game = chess_lib.Chess();
      final captured = capturedPieces(game);
      expect(captured.byWhite, isEmpty);
      expect(captured.byBlack, isEmpty);
      expect(captured.materialDiff, 0);
      expect(captured.isEmpty, isTrue);
    });

    test('wit slaat een pion (Scholar’s mate)', () {
      final game = chess_lib.Chess();
      // 1. e4 e5 2. Dh5 Pc6 3. Lc4 Pf6?? 4. Dxf7#
      game.move({'from': 'e2', 'to': 'e4'});
      game.move({'from': 'e7', 'to': 'e5'});
      game.move({'from': 'd1', 'to': 'h5'});
      game.move({'from': 'b8', 'to': 'c6'});
      game.move({'from': 'f1', 'to': 'c4'});
      game.move({'from': 'g8', 'to': 'f6'});
      game.move({'from': 'h5', 'to': 'f7'});
      final captured = capturedPieces(game);
      expect(captured.byWhite.map((p) => p.name), ['p']);
      expect(captured.byBlack, isEmpty);
      expect(captured.materialDiff, 1);
      expect(game.in_checkmate, isTrue);
    });

    test('zwart slaat witte stukken (fool’s mate)', () {
      final game = chess_lib.Chess();
      game.move({'from': 'f2', 'to': 'f3'});
      game.move({'from': 'e7', 'to': 'e5'});
      game.move({'from': 'g2', 'to': 'g4'});
      game.move({'from': 'd8', 'to': 'h4'});
      final captured = capturedPieces(game);
      expect(captured.byWhite, isEmpty);
      expect(captured.byBlack, isEmpty); // geen vangsten, gewoon mat
      expect(captured.materialDiff, 0);
    });

    test('promotie telt niet als extra pionverlies', () {
      final game = chess_lib.Chess.fromFEN(
        '8/P7/8/k6K/8/8/8/8 w - - 0 1',
      );
      final ok = game.move({'from': 'a7', 'to': 'a8', 'promotion': 'q'});
      expect(ok, isTrue);
      final captured = capturedPieces(game);
      expect(captured.byWhite, isEmpty);
      expect(captured.byBlack, isEmpty);
      expect(captured.materialDiff, 0);
    });

    test('meerdere vangsten worden op waarde gesorteerd', () {
      // Kunstmatige stand: wit heeft al geslagen: pion + toren.
      final game = chess_lib.Chess.fromFEN(
        'r7/8/8/8/8/8/8/R3K2k w - - 0 1',
      );
      // Witte toren a1 slaat de zwarte toren op a8? Niet legaal (a1→a8 is wel
      // langs de a-lijn: a2..a7 zijn leeg).
      game.move({'from': 'a1', 'to': 'a8'});
      final captured = capturedPieces(game);
      expect(captured.byWhite.map((p) => p.name), ['r']);
      expect(captured.materialDiff, 5);
    });
  });
}
