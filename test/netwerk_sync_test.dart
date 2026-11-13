// Integratietest over localhost: een echte host en joiner, echte WebSocket,
// echte FEN-synchronisatie. Verifieert dat een zet van de host bij de joiner
// aankomt en dat zetten alleen aan de beurt-speler zijn toegestaan.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_multiplayer/services/p2p_chess_service.dart';

Future<bool> _waitFor(bool Function() condition,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return condition();
}

void main() {
  test('host en joiner synchroniseren een zet via WebSocket', () async {
    final host = P2PChessService();
    final joiner = P2PChessService();
    addTearDown(() async {
      await host.leaveGame();
      await joiner.leaveGame();
    });

    expect(await host.startHost(port: 8091), isTrue);
    expect(await joiner.joinGame('127.0.0.1', 8091), isTrue);

    // Host accepteert de verbinding en stuurt init; joiner markeert zichzelf zwart.
    expect(await _waitFor(() => host.connectionState == ChessConnectionState.connected),
        isTrue,
        reason: 'host zag de joiner niet binnen 5s');
    expect(joiner.playerColor, 'b');
    expect(host.playerColor, 'w');

    // Wit (host) opent met e4.
    host.syncLocalMove('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1');

    final gesynchroniseerd = await _waitFor(
      () => joiner.game.fen == 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
    );
    expect(gesynchroniseerd, isTrue,
        reason: 'De joiner heeft de zet van de host nooit ontvangen');

    // Na e4 is zwart aan zet: zwart mag zetten, wit niet.
    expect(joiner.isMyTurn, isTrue);
    expect(host.isMyTurn, isFalse);

    // Reset stuurt beide kanten terug naar de beginstelling.
    joiner.resetGame();
    final gereset = await _waitFor(() => host.game.fen == P2PChessService.initialFen);
    expect(gereset, isTrue);
  });
}
