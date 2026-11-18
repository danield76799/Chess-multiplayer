import 'package:flutter/material.dart';

import '../services/game_review.dart';
import '../theme.dart';

/// Toont de uitkomst van de partij-analyse in een bottom sheet.
Future<void> showGameReviewSheet(
  BuildContext context, {
  required GameReview review,
  required String sideLabel,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: ChessTheme.surfaceHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _GameReviewSheet(review: review, sideLabel: sideLabel),
  );
}

class _GameReviewSheet extends StatelessWidget {
  const _GameReviewSheet({required this.review, required this.sideLabel});

  final GameReview review;
  final String sideLabel;

  @override
  Widget build(BuildContext context) {
    final worst = review.worst;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🔎', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                const Text(
                  'Bespreking van de partij',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ChessTheme.gold,
                  ),
                ),
                const Spacer(),
                Text(
                  sideLabel,
                  style: const TextStyle(color: ChessTheme.textDim, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (review.clean) ...[
              const Text(
                'Geen serieuze fouten — knap gespeeld! 👏',
                style: TextStyle(fontSize: 16, color: ChessTheme.text),
              ),
            ] else ...[
              Row(
                children: [
                  _Badge(label: 'blunders', value: review.blunders, color: ChessTheme.red),
                  const SizedBox(width: 10),
                  _Badge(label: 'fouten', value: review.mistakes, color: const Color(0xFFFFC078)),
                  const SizedBox(width: 10),
                  _Badge(label: 'kleine foutjes', value: review.inaccuracies, color: ChessTheme.textDim),
                ],
              ),
              if (worst != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ChessTheme.gold.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Grootste moment: zet ${worst.moveNumber}… ${worst.san}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: ChessTheme.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              worst.bestSan != null
                                  ? 'Beter was ${worst.bestSan}. Kijk nog eens naar die stelling na het potje.'
                                  : 'Kijk nog eens goed naar die stelling na het potje.',
                              style: const TextStyle(color: ChessTheme.textDim, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Sluiten'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
            ),
            Text(label, style: const TextStyle(fontSize: 11, color: ChessTheme.text)),
          ],
        ),
      ),
    );
  }
}
