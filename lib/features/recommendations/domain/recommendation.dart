import 'package:tourism_mobile/features/routes/domain/route.dart';

enum RecommendationExplanation {
  matchesInterest,
  nearbyExploration,
  freshRoute,
  popularRoute,
  coldStart,
}

String recommendationExplanationLabel(RecommendationExplanation value) {
  return switch (value) {
    RecommendationExplanation.matchesInterest => 'Подходит под ваши интересы',
    RecommendationExplanation.nearbyExploration => 'Недалеко от вас',
    RecommendationExplanation.freshRoute => 'Новый маршрут',
    RecommendationExplanation.popularRoute => 'Популярен у путешественников',
    RecommendationExplanation.coldStart => 'Хороший вариант для знакомства',
  };
}

RecommendationExplanation recommendationExplanationFromJson(Object? value) {
  return switch (value) {
    'matches_interest' => RecommendationExplanation.matchesInterest,
    'nearby_exploration' => RecommendationExplanation.nearbyExploration,
    'fresh_route' => RecommendationExplanation.freshRoute,
    'popular_route' => RecommendationExplanation.popularRoute,
    _ => RecommendationExplanation.coldStart,
  };
}

class RecommendationCard {
  const RecommendationCard({
    required this.route,
    required this.rank,
    required this.score,
    required this.explanation,
    required this.exploration,
  });

  final RouteSummary route;
  final int rank;
  final double score;
  final RecommendationExplanation explanation;
  final bool exploration;

  factory RecommendationCard.fromJson(Map<String, dynamic> json) {
    return RecommendationCard(
      route: RouteSummary.fromJson(
        Map<String, dynamic>.from(json['route'] as Map),
      ),
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      explanation: recommendationExplanationFromJson(json['explanation_code']),
      exploration: json['exploration'] as bool? ?? false,
    );
  }
}

class RecommendationDeck {
  const RecommendationDeck({
    required this.deckDate,
    required this.rankerVersion,
    required this.generated,
    required this.items,
    required this.remaining,
  });

  final DateTime deckDate;
  final String rankerVersion;
  final bool generated;
  final List<RecommendationCard> items;
  final int remaining;

  factory RecommendationDeck.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return RecommendationDeck(
      deckDate:
          DateTime.tryParse(json['deck_date'] as String? ?? '') ??
          DateTime.now(),
      rankerVersion: json['ranker_version'] as String? ?? 'unknown',
      generated: json['generated'] as bool? ?? false,
      items: rawItems is List
          ? rawItems
                .whereType<Map<dynamic, dynamic>>()
                .map(
                  (item) => RecommendationCard.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    );
  }
}
