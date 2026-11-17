// Basis-tests voor de P2P-schaakapp:
// 1. De menu-widget rendert zonder netwerk/verbinding.
// 2. De spelregels/turn-logica in de service werkt los van het netwerk.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:chess_multiplayer/main.dart';
import 'package:chess_multiplayer/services/p2p_chess_service.dart';

void main() {
  testWidgets('Opstartscherm toont de twee spelmodi', (tester) async {
    // Labels passen niet in de standaard testviewport; vergroot hem.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => P2PChessService(),
        child: const MyApp(),
      ),
    );
    expect(find.text('Schaken!'), findsOneWidget);
    expect(find.text('Tegen de computer'), findsOneWidget);
    expect(find.text('Met een vriend'), findsOneWidget);

    // Via de lobby-knop kom je op het multiplayer-scherm.
    await tester.tap(find.text('🎈  Naar de lobby'));
    await tester.pumpAndSettle();
    expect(find.text('Nieuw spel host'), findsOneWidget);
    expect(find.text('Zoeken'), findsOneWidget);
    expect(find.text('Verbinden met host'), findsOneWidget);
  });

  group('P2PChessService spelregels', () {
    test('wit mag als eerste zetten, zwart niet', () {
      final service = P2PChessService();
      // Nog niet verbonden: niemand mag zetten.
      expect(service.isMyTurn, isFalse);

      // Simuleer een verbonden witte speler (host).
      service.playerColor = 'w';
      service.connectionState = ChessConnectionState.connected;
      expect(service.isMyTurn, isTrue);

      // Simuleer een verbonden zwarte speler (joiner): zwart mag pas na wit.
      final black = P2PChessService();
      black.playerColor = 'b';
      black.connectionState = ChessConnectionState.connected;
      expect(black.isMyTurn, isFalse);
    });

    test('gameStatus detecteert mat', () {
      final service = P2PChessService();
      expect(service.gameStatus, 'ongoing');

      // Fool's mate: 1. f3 e5 2. g4 Qh4#
      service.game.move({'from': 'f2', 'to': 'f3'});
      service.game.move({'from': 'e7', 'to': 'e5'});
      service.game.move({'from': 'g2', 'to': 'g4'});
      service.game.move({'from': 'd8', 'to': 'h4'});
      expect(service.game.in_checkmate, isTrue);
      expect(service.gameStatus, 'checkmate');
      expect(service.gameOverMessage, contains('Schaakmat'));
    });

    test('initial fen is de standaard beginstelling', () {
      expect(
        P2PChessService.initialFen,
        startsWith('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR'),
      );
    });
  });
}
