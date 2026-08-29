import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/recommendations/domain/recommendation.dart';
import 'package:tourism_mobile/features/recommendations/domain/recommendation_repository.dart';

class ApiRecommendationRepository implements RecommendationRepository {
  ApiRecommendationRepository(this._dio);

  final Dio _dio;

  @override
  Future<RecommendationDeck> getToday() {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/routes/recommendations/today',
      );
      return RecommendationDeck.fromJson(response.data!);
    });
  }

  @override
  Future<void> skip({
    required String routeId,
    required String clientEventId,
    required DateTime deckDate,
    required String rankerVersion,
  }) {
    return guardApiCall(() async {
      await _dio.post<void>(
        '/api/v1/routes/$routeId/recommendation-feedback',
        data: {
          'action': 'skip',
          'client_event_id': clientEventId,
          'deck_date': deckDate.toIso8601String().split('T').first,
          'ranker_version': rankerVersion,
        },
      );
    });
  }
}
