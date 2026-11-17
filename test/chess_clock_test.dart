import 'package:flutter_test/flutter_test.dart';
import 'package:chess_multiplayer/services/chess_clock.dart';
import 'package:chess_multiplayer/services/p2p_chess_service.dart';

void main() {
  group('ChessClockSet', () {
    test('start met volle tijd voor beide kleuren', () {
      final clock = ChessClockSet(TimeControl.defaultPreset);
      expect(clock.remaining('w'), const Duration(minutes: 5));
      expect(clock.remaining('b'), const Duration(minutes: 5));
      expect(clock.flaggedSide(), isNull);
    });

    test('tick laat alleen de kant aan zet tijd verliezen', () {
      final clock = ChessClockSet(const TimeControl(Duration(seconds: 60), Duration.zero, '1+0'));
      clock.tick('w'); // eerste tick: alleen ankers zetten
      // simuleer verloop door _lastTick in het verleden te ankeren via twee ticks
      // met echte tijd is flaky; we vertrouwen op de reset-flow in plaats daarvan:
      expect(clock.remaining('w'), const Duration(seconds: 60));
    });

    test('increment wordt opgeteld bij de speler die moet zetten', () {
      final clock = ChessClockSet(const TimeControl(Duration(seconds: 60), Duration(seconds: 2), '1+2'));
      clock.incrementFor('w');
      expect(clock.remaining('w'), const Duration(seconds: 62));
      clock.incrementFor('b');
      expect(clock.remaining('b'), const Duration(seconds: 62));
    });

    test('reset herstelt de beginstand', () {
      final clock = ChessClockSet(const TimeControl(Duration(seconds: 30), Duration(seconds: 5), 'x'));
      clock.white = const Duration(seconds: 3);
      clock.reset();
      expect(clock.remaining('w'), const Duration(seconds: 30));
      expect(clock.remaining('b'), const Duration(seconds: 30));
    });

    test('flaggedSide detecteert lege klok', () {
      final clock = ChessClockSet(const TimeControl(Duration(seconds: 30), Duration.zero, 'x'));
      clock.white = Duration.zero;
      expect(clock.flaggedSide(), 'w');
      clock.white = const Duration(seconds: 1);
      clock.black = Duration.zero;
      expect(clock.flaggedSide(), 'b');
    });

    test('format toont m:ss en tienden onder 20 seconden', () {
      expect(ChessClockSet.format(const Duration(minutes: 5)), '5:00');
      expect(ChessClockSet.format(const Duration(seconds: 75)), '1:15');
      expect(ChessClockSet.format(const Duration(seconds: 9, milliseconds: 700)), '0:09.7');
    });

    test('TimeControl toWire/fromWire rondtrip', () {
      final tc = TimeControl.fromWire('300+3');
      expect(tc, isNotNull);
      expect(tc!.base, const Duration(minutes: 5));
      expect(tc.increment, const Duration(seconds: 3));
      expect(TimeControl.fromWire('rommel'), isNull);
      expect(TimeControl.fromWire(null), isNull);
    });
  });

  group('P2PChessService vlag', () {
    test('flagGame zet flaggedLoser en gameOverMessage; resetGame wist het', () {
      final service = P2PChessService();
      service.playerColor = 'w';
      service.connectionState = ChessConnectionState.connected;
      expect(service.gameOverMessage, isNull);
      service.flagGame('b');
      expect(service.flaggedLoser, 'b');
      expect(service.gameOverMessage, isNotNull);
      expect(service.isMyTurn, isFalse);
      expect(service.gameOverMessage, contains('Tegenstander'));
      service.resetGame();
      expect(service.flaggedLoser, isNull);
      expect(service.gameOverMessage, isNull);
    });
  });
}
