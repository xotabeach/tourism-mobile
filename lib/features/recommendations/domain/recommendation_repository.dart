import 'package:tourism_mobile/features/recommendations/domain/recommendation.dart';

abstract interface class RecommendationRepository {
  Future<RecommendationDeck> getToday();

  /// Rebuilds today's deck server-side and returns the fresh one.
  Future<RecommendationDeck> refreshToday();

  Future<void> skip({
    required String routeId,
    required String clientEventId,
    required DateTime deckDate,
    required String rankerVersion,
  });
}
