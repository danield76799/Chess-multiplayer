import 'package:chess_multiplayer/services/game_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameReviewService', () {
    test('herkent de fatale blunder in de schaakmat van de dwaas', () {
      final review = GameReviewService.analyze(
        ['f3', 'e5', 'g4', 'Qh4#'],
        reviewWhite: true,
      );
      expect(review.blunders, greaterThanOrEqualTo(1));
      expect(review.worst, isNotNull);
      expect(review.worst!.san, 'g4');
      expect(review.worst!.lossCp, greaterThanOrEqualTo(1000));
    });

    test('zwart maakt geen blunders in dezelfde partij', () {
      final review = GameReviewService.analyze(
        ['f3', 'e5', 'g4', 'Qh4#'],
        reviewWhite: false,
      );
      expect(review.blunders, 0);
      expect(review.mistakes, 0);
    });

    test('rustige opening zonder fouten meldt geen blunders', () {
      final review = GameReviewService.analyze(
        ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6'],
        reviewWhite: true,
      );
      expect(review.blunders, 0);
    });
  });
}
