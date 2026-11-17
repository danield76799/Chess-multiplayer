import 'package:chess/chess.dart';

/// Een klein stukje historie: welke zet deed de tegenstander als laatste?
class LastOpponentMove {
  final String san;
  final String from;
  final String to;
  const LastOpponentMove({required this.san, required this.from, required this.to});
}

/// Geeft de laatste zet van de *tegenstander* terug (niet die van de
/// lokale speler), of null als die er nog niet is.
///
/// [localIsWhite] geeft aan of de lokale speler met wit speelt.
LastOpponentMove? lastOpponentMove(Chess game, {required bool localIsWhite}) {
  // verbose: lijst met {san, from, to, ...} in zetten-volgorde.
  final history = game.getHistory({'verbose': true});
  // Even index = witte zet, oneven = zwarte zet.
  for (var i = history.length - 1; i >= 0; i--) {
    final isWhiteMove = i.isEven;
    if (isWhiteMove == localIsWhite) continue;
    final m = history[i] as Map;
    return LastOpponentMove(
      san: (m['san'] ?? '?').toString(),
      from: (m['from'] ?? '').toString(),
      to: (m['to'] ?? '').toString(),
    );
  }
  return null;
}
