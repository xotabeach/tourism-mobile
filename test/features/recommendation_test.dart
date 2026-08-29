import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/recommendations/domain/recommendation.dart';

void main() {
  test(
    'parses daily recommendation deck with nested route and explanation',
    () {
      final deck = RecommendationDeck.fromJson({
        'deck_date': '2026-08-29',
        'ranker_version': 'v1',
        'generated': true,
        'remaining': 2,
        'items': [
          {
            'rank': 1,
            'score': 0.82,
            'explanation_code': 'matches_interest',
            'exploration': false,
            'route': {
              'id': 'route-1',
              'name': 'Южный берег',
              'slug': 'south-coast',
              'short_description': 'Море и дворцы',
              'stops_count': 3,
            },
          },
        ],
      });

      expect(deck.items, hasLength(1));
      expect(deck.items.single.route.name, 'Южный берег');
      expect(
        deck.items.single.explanation,
        RecommendationExplanation.matchesInterest,
      );
      expect(deck.items.single.score, 0.82);
    },
  );
}
