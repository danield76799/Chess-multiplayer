import 'package:chess_multiplayer/services/chess_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('telt winst, verlies en remise apart per modus', () async {
    await ChessStats.recordResult(vsAi: true, playerWon: true);
    await ChessStats.recordResult(vsAi: true, playerWon: true);
    await ChessStats.recordResult(vsAi: true, playerWon: false);
    await ChessStats.recordResult(vsAi: true, playerWon: null);
    await ChessStats.recordResult(vsAi: false, playerWon: true);

    final ai = await ChessStats.load(vsAi: true);
    final wifi = await ChessStats.load(vsAi: false);

    expect(ai.wins, 2);
    expect(ai.losses, 1);
    expect(ai.draws, 1);
    expect(ai.played, 4);
    expect(wifi.wins, 1);
    expect(wifi.played, 1);
  });

  test('reeks telt wins, verliest bij verlies of remise, en onthoudt beste', () async {
    for (var i = 0; i < 3; i++) {
      await ChessStats.recordResult(vsAi: true, playerWon: true);
    }
    var s = await ChessStats.load(vsAi: true);
    expect(s.streak, 3);
    expect(s.bestStreak, 3);

    await ChessStats.recordResult(vsAi: true, playerWon: false);
    s = await ChessStats.load(vsAi: true);
    expect(s.streak, 0);
    expect(s.bestStreak, 3);

    await ChessStats.recordResult(vsAi: true, playerWon: true);
    s = await ChessStats.load(vsAi: true);
    expect(s.streak, 1);
    expect(s.bestStreak, 3);
  });

  test('resetAll wist alles', () async {
    await ChessStats.recordResult(vsAi: true, playerWon: true);
    await ChessStats.recordResult(vsAi: false, playerWon: false);
    await ChessStats.resetAll();
    final ai = await ChessStats.load(vsAi: true);
    final wifi = await ChessStats.load(vsAi: false);
    expect(ai.played, 0);
    expect(wifi.played, 0);
  });
}
