import 'package:flutter/foundation.dart';
import 'package:chess_multiplayer/services/chess_ai.dart';
import 'package:chess/chess.dart';

void main() {
  final counts = <String, int>{};
  for (var i = 0; i < 60; i++) {
    final g = Chess();
    final m = ChessAI.pickMove(g, difficulty: AIDifficulty.normaal);
    if (m != null) {
      counts[m.fromAlgebraic + m.toAlgebraic] = (counts[m.fromAlgebraic + m.toAlgebraic] ?? 0) + 1;
    }
  }
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sorted) {
    debugPrint('${e.key}: ${e.value}x');
  }
}
