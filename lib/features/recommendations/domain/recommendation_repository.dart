import 'package:tourism_mobile/features/recommendations/domain/recommendation.dart';

abstract interface class RecommendationRepository {
  Future<RecommendationDeck> getToday();

  Future<void> skip({
    required String routeId,
    required String clientEventId,
    required DateTime deckDate,
    required String rankerVersion,
  });
}
