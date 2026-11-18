import 'package:flutter_test/flutter_test.dart';
import 'package:chess_multiplayer/services/p2p_chess_service.dart';

void main() {
  test('bij een plotselinge verbreking verbinden beide kanten opnieuw', () async {
    final host = P2PChessService();
    final joiner = P2PChessService();

    expect(await host.startHost(port: 18099), isTrue);
    expect(await joiner.joinGame('127.0.0.1', 18099), isTrue);
    expect(host.connectionState, ChessConnectionState.connected);
    expect(joiner.connectionState, ChessConnectionState.connected);

    // Simuleer een plotselinge verbindingsonderbreking (joiner-zijde)
    await joiner.debugDropConnection();

    // Beide kanten moeten binnen ~12 seconden weer CONNECTED zijn
    var ok = false;
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (host.connectionState == ChessConnectionState.connected &&
          joiner.connectionState == ChessConnectionState.connected) {
        ok = true;
        break;
      }
    }
    expect(ok, isTrue,
        reason: 'host=${host.connectionState}, joiner=${joiner.connectionState}, '
            'hostErr=${host.errorMessage}, joinerErr=${joiner.errorMessage}');

    await host.leaveGame();
    await joiner.leaveGame();
  }, timeout: const Timeout(Duration(seconds: 20)));
}
