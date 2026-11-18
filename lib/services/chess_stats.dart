import 'package:shared_preferences/shared_preferences.dart';

/// Cumulatieve spelstatistieken, lokaal opgeslagen.
///
/// Bijgehouden per modus: tegen de computer (`vsAi: true`) of via wifi
/// (`vsAi: false`). Geen netwerk, geen account — gewoon in SharedPreferences.
class ChessStats {
  static const _prefix = 'chess_stats_v1_';

  static String _k(bool vsAi, String name) =>
      '$_prefix${vsAi ? 'ai' : 'wifi'}_$name';

  /// Legt het resultaat van één partij vast.
  /// [playerWon]: true = gewonnen, false = verloren, null = remise.
  static Future<void> recordResult({
    required bool vsAi,
    required bool? playerWon,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var streak = prefs.getInt(_k(vsAi, 'streak')) ?? 0;
    var best = prefs.getInt(_k(vsAi, 'bestStreak')) ?? 0;

    if (playerWon == true) {
      streak += 1;
      if (streak > best) best = streak;
      await prefs.setInt(_k(vsAi, 'wins'), (prefs.getInt(_k(vsAi, 'wins')) ?? 0) + 1);
      await prefs.setInt(_k(vsAi, 'bestStreak'), best);
    } else if (playerWon == false) {
      streak = 0;
      await prefs.setInt(_k(vsAi, 'losses'), (prefs.getInt(_k(vsAi, 'losses')) ?? 0) + 1);
    } else {
      streak = 0;
      await prefs.setInt(_k(vsAi, 'draws'), (prefs.getInt(_k(vsAi, 'draws')) ?? 0) + 1);
    }
    await prefs.setInt(_k(vsAi, 'streak'), streak);
  }

  static Future<ModeStats> load({required bool vsAi}) async {
    final prefs = await SharedPreferences.getInstance();
    return ModeStats(
      wins: prefs.getInt(_k(vsAi, 'wins')) ?? 0,
      losses: prefs.getInt(_k(vsAi, 'losses')) ?? 0,
      draws: prefs.getInt(_k(vsAi, 'draws')) ?? 0,
      streak: prefs.getInt(_k(vsAi, 'streak')) ?? 0,
      bestStreak: prefs.getInt(_k(vsAi, 'bestStreak')) ?? 0,
    );
  }

  /// Wist alle statistieken (beide modus-sloten).
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final vsAi in [true, false]) {
      for (final k in ['wins', 'losses', 'draws', 'streak', 'bestStreak']) {
        await prefs.remove(_k(vsAi, k));
      }
    }
  }
}

class ModeStats {
  final int wins;
  final int losses;
  final int draws;
  final int streak;
  final int bestStreak;

  const ModeStats({
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.streak = 0,
    this.bestStreak = 0,
  });

  int get played => wins + losses + draws;
  bool get isEmpty => played == 0;
}
