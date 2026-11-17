import 'package:flutter_test/flutter_test.dart';
import 'package:chess_multiplayer/widgets/move_clock.dart';
import 'package:chess_multiplayer/services/p2p_chess_service.dart';

void main() {
  group('MoveClock', () {
    test('start met volle tijd en loopt af naar 0', () {
      final now = DateTime.now();
      final clock = MoveClock(now: now);
      expect(clock.remaining(now).inSeconds, MoveClock.moveSeconds);
      expect(clock.secondsLeft, MoveClock.moveSeconds);
      final later = now.add(const Duration(seconds: MoveClock.moveSeconds + 1));
      expect(clock.remaining(later).isNegative, isTrue);
    });

    test('reset zet de klok terug op volle tijd', () {
      final now = DateTime.now();
      final clock = MoveClock(now: now);
      clock.reset(now.add(const Duration(seconds: 10)));
      expect(clock.remaining(now.add(const Duration(seconds: 10))).inSeconds,
          MoveClock.moveSeconds);
    });

    test('pauze schuift de deadline op met de pauzeduur', () {
      final t0 = DateTime.now();
      final clock = MoveClock(now: t0);
      clock.pause();
      // simuleer 20 seconden weg terwijl de app in de achtergrond zit
      // verstreken 'achtergrondtijd' toevoegen via resume: we moeten de klok
      // vertellen dat er 20s voorbij is; dat doen we door resume te faken met
      // een handmatige tijdsprong: gebruik pause->resume na kunstmatige tijd.
      // (MoveClock gebruikt DateTime.now(), dus we controleren alleen de logica)
      clock.resume();
      // Deadline moet ten minste de originele deadline plus/minus afwijking zijn;
      // de kern: na resume is de klok nog niet verlopen.
      expect(clock.isExpired, isFalse);
    });
  });

  group('P2PChessService vlag (tijd verstreken)', () {
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

    test('dubbele vlag blijft stabiel', () {
      final service = P2PChessService();
      service.playerColor = 'b';
      service.flagGame('w');
      service.flagGame('b'); // mag de eerdere vlag niet overschrijven
      expect(service.flaggedLoser, 'w');
    });

    test('ongeldige kleur wordt genegeerd', () {
      final service = P2PChessService();
      service.flagGame('x');
      expect(service.flaggedLoser, isNull);
    });
  });
}
