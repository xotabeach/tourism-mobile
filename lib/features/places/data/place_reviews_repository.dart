import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/routes/data/route_reviews_repository.dart';

abstract interface class PlaceReviewsRepository {
  Future<RouteReviewsPage> listPublished(String placeId);
  Future<RouteReview> submit({
    required String placeId,
    required String body,
    required int rating,
    List<String> imagePaths = const [],
    String? replyToReviewId,
  });
  Future<void> delete({required String placeId, required String reviewId});
  Future<List<RouteReview>> listMine();
}

final class ApiPlaceReviewsRepository implements PlaceReviewsRepository {
  ApiPlaceReviewsRepository(this._dio);

  final Dio _dio;

  @override
  Future<RouteReviewsPage> listPublished(String placeId) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/places/$placeId/reviews',
        queryParameters: const {'limit': 50, 'offset': 0},
      );
      final data = response.data;
      if (data == null) throw const UnexpectedFailure();
      final raw = data['items'];
      return RouteReviewsPage(
        items: raw is List
            ? [
                for (final item in raw)
                  if (item is Map<String, dynamic>) RouteReview.fromJson(item),
              ]
            : const [],
        total: (data['total'] as num?)?.toInt() ?? 0,
        averageRating: (data['average_rating'] as num?)?.toDouble(),
        ratingCount: (data['rating_count'] as num?)?.toInt() ?? 0,
      );
    });
  }

  @override
  Future<RouteReview> submit({
    required String placeId,
    required String body,
    required int rating,
    List<String> imagePaths = const [],
    String? replyToReviewId,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/places/$placeId/reviews',
        data: {
          'body': body,
          'rating': rating,
          'reply_to_review_id': ?replyToReviewId,
        },
      );
      final data = response.data;
      if (data == null) throw const UnexpectedFailure();
      var review = RouteReview.fromJson(data);
      final media = <RouteReviewMedia>[];
      for (var position = 0; position < imagePaths.length; position++) {
        final upload = await _dio.post<Map<String, dynamic>>(
          '/api/v1/places/$placeId/reviews/${review.id}/media',
          data: FormData.fromMap({
            'position': position,
            'file': await MultipartFile.fromFile(imagePaths[position]),
          }),
        );
        if (upload.data == null) throw const UnexpectedFailure();
        media.add(RouteReviewMedia.fromJson(upload.data!));
      }
      if (media.isNotEmpty) {
        review = RouteReview(
          id: review.id,
          routeId: review.routeId,
          authorUserId: review.authorUserId,
          authorDisplayName: review.authorDisplayName,
          authorRankTitle: review.authorRankTitle,
          authorAvatarUrl: review.authorAvatarUrl,
          body: review.body,
          rating: review.rating,
          status: review.status,
          createdAt: review.createdAt,
          media: media,
          replyTo: review.replyTo,
        );
      }
      return review;
    });
  }

  @override
  Future<void> delete({required String placeId, required String reviewId}) {
    return guardApiCall(() async {
      await _dio.delete<void>('/api/v1/places/$placeId/reviews/$reviewId');
    });
  }

  @override
  Future<List<RouteReview>> listMine() {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/me/place-reviews',
        queryParameters: const {'limit': 50, 'offset': 0},
      );
      final raw = response.data?['items'];
      return raw is List
          ? [
              for (final item in raw)
                if (item is Map<String, dynamic>) RouteReview.fromJson(item),
            ]
          : const [];
    });
  }
}

final class MockPlaceReviewsRepository implements PlaceReviewsRepository {
  @override
  Future<RouteReviewsPage> listPublished(String placeId) async {
    return RouteReviewsPage(
      items: [
        RouteReview(
          id: 'mock-place-review',
          routeId: placeId,
          authorUserId: 'mock-maria',
          authorDisplayName: 'Мария Крымская',
          authorRankTitle: 'Исследователь',
          body:
              'Красивое место и отличный вид. Лучше приезжать утром, пока '
              'на смотровой площадке немного людей.',
          rating: 5,
          status: 'published',
          createdAt: DateTime.utc(2026, 8, 1),
        ),
      ],
      total: 1,
      ratingCount: 1,
      averageRating: 5,
    );
  }

  @override
  Future<RouteReview> submit({
    required String placeId,
    required String body,
    required int rating,
    List<String> imagePaths = const [],
    String? replyToReviewId,
  }) async {
    return RouteReview(
      id: 'mock-place-review-new',
      routeId: placeId,
      authorUserId: 'mock-user',
      authorDisplayName: 'Вы',
      authorRankTitle: 'Новичок',
      body: body,
      rating: rating,
      status: 'pending_review',
      createdAt: DateTime.now().toUtc(),
      media: [
        for (var i = 0; i < imagePaths.length; i++)
          RouteReviewMedia(
            id: 'mock-place-media-$i',
            url: imagePaths[i],
            sortOrder: i,
          ),
      ],
    );
  }

  @override
  Future<void> delete({
    required String placeId,
    required String reviewId,
  }) async {}

  @override
  Future<List<RouteReview>> listMine() async => const [];
}

final placeReviewsRepositoryProvider = Provider<PlaceReviewsRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) return MockPlaceReviewsRepository();
  return ApiPlaceReviewsRepository(ref.watch(dioProvider));
});
