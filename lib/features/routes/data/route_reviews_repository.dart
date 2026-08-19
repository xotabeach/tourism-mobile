import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';

class RouteReviewMedia {
  const RouteReviewMedia({
    required this.id,
    required this.url,
    required this.sortOrder,
    this.width,
    this.height,
  });

  final String id;
  final String url;
  final int? width;
  final int? height;
  final int sortOrder;

  factory RouteReviewMedia.fromJson(Map<String, dynamic> json) {
    return RouteReviewMedia(
      id: json['id'] as String,
      url: json['url'] as String,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class RouteReviewReply {
  const RouteReviewReply({
    required this.reviewId,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.body,
  });

  final String reviewId;
  final String authorUserId;
  final String authorDisplayName;
  final String body;

  factory RouteReviewReply.fromJson(Map<String, dynamic> json) {
    return RouteReviewReply(
      reviewId: json['review_id'] as String,
      authorUserId: json['author_user_id'] as String,
      authorDisplayName:
          json['author_display_name'] as String? ?? 'Путешественник',
      body: json['body'] as String? ?? '',
    );
  }
}

class RouteReview {
  const RouteReview({
    required this.id,
    required this.routeId,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.authorRankTitle,
    required this.body,
    required this.rating,
    required this.status,
    required this.createdAt,
    this.authorAvatarUrl,
    this.media = const [],
    this.replyTo,
  });

  final String id;
  final String routeId;
  final String authorUserId;
  final String authorDisplayName;
  final String authorRankTitle;
  final String? authorAvatarUrl;
  final String body;
  final int rating;
  final String status;
  final DateTime createdAt;
  final List<RouteReviewMedia> media;
  final RouteReviewReply? replyTo;

  factory RouteReview.fromJson(Map<String, dynamic> json) {
    return RouteReview(
      id: json['id'] as String,
      routeId: json['route_id'] as String,
      authorUserId: json['author_user_id'] as String,
      authorDisplayName:
          json['author_display_name'] as String? ?? 'Путешественник',
      authorRankTitle: json['author_rank_title'] as String? ?? 'Новичок',
      authorAvatarUrl: json['author_avatar_url'] as String?,
      body: json['body'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'published',
      createdAt: DateTime.parse(json['created_at'] as String),
      media: switch (json['media']) {
        final List<dynamic> items => [
          for (final item in items)
            if (item is Map<String, dynamic>) RouteReviewMedia.fromJson(item),
        ],
        _ => const [],
      },
      replyTo: switch (json['reply_to']) {
        final Map<String, dynamic> value => RouteReviewReply.fromJson(value),
        _ => null,
      },
    );
  }
}

class RouteReviewsPage {
  const RouteReviewsPage({
    required this.items,
    required this.total,
    required this.ratingCount,
    this.averageRating,
  });

  final List<RouteReview> items;
  final int total;
  final double? averageRating;
  final int ratingCount;
}

abstract interface class RouteReviewsRepository {
  Future<RouteReviewsPage> listPublished(String routeId);
  Future<RouteReview> submit({
    required String routeId,
    required String body,
    required int rating,
    List<String> imagePaths = const [],
    String? replyToReviewId,
  });
  Future<void> delete({required String routeId, required String reviewId});
  Future<void> deleteMedia({
    required String routeId,
    required String reviewId,
    required String mediaId,
  });
  Future<List<RouteReview>> listMine();
}

final class ApiRouteReviewsRepository implements RouteReviewsRepository {
  ApiRouteReviewsRepository(this._dio);

  final Dio _dio;

  @override
  Future<RouteReviewsPage> listPublished(String routeId) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/routes/$routeId/reviews',
        queryParameters: const {'limit': 50, 'offset': 0},
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
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
    required String routeId,
    required String body,
    required int rating,
    List<String> imagePaths = const [],
    String? replyToReviewId,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/routes/$routeId/reviews',
        data: {
          'body': body,
          'rating': rating,
          'reply_to_review_id': ?replyToReviewId,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      var review = RouteReview.fromJson(data);
      final uploaded = <RouteReviewMedia>[];
      for (var position = 0; position < imagePaths.length; position++) {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/routes/$routeId/reviews/${review.id}/media',
          data: FormData.fromMap({
            'position': position,
            'file': await MultipartFile.fromFile(imagePaths[position]),
          }),
        );
        final mediaData = response.data;
        if (mediaData == null) {
          throw const UnexpectedFailure();
        }
        uploaded.add(RouteReviewMedia.fromJson(mediaData));
      }
      if (uploaded.isNotEmpty) {
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
          media: uploaded,
          replyTo: review.replyTo,
        );
      }
      return review;
    });
  }

  @override
  Future<void> delete({required String routeId, required String reviewId}) {
    return guardApiCall(() async {
      await _dio.delete<void>('/api/v1/routes/$routeId/reviews/$reviewId');
    });
  }

  @override
  Future<void> deleteMedia({
    required String routeId,
    required String reviewId,
    required String mediaId,
  }) {
    return guardApiCall(() async {
      await _dio.delete<void>(
        '/api/v1/routes/$routeId/reviews/$reviewId/media/$mediaId',
      );
    });
  }

  @override
  Future<List<RouteReview>> listMine() {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/me/reviews',
        queryParameters: const {'limit': 50, 'offset': 0},
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      final raw = data['items'];
      if (raw is! List) {
        return const [];
      }
      return [
        for (final item in raw)
          if (item is Map<String, dynamic>) RouteReview.fromJson(item),
      ];
    });
  }
}

final class MockRouteReviewsRepository implements RouteReviewsRepository {
  static final _sample = RouteReview(
    id: 'mock-r1',
    routeId: 'mock',
    authorUserId: 'u1',
    authorDisplayName: 'Никита',
    authorRankTitle: 'Продвинутый пешеход',
    body:
        'По-моему скромному мнению, если смотреть через призму моего '
        'пешеходного опыта, маршрут не достаточно интересен с точки зрения '
        'сложности, не смотря на третий уровень. В остальном, новичкам '
        'понравится.',
    rating: 4,
    status: 'published',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  @override
  Future<RouteReviewsPage> listPublished(String routeId) async {
    return RouteReviewsPage(
      items: [
        RouteReview(
          id: _sample.id,
          routeId: routeId,
          authorUserId: _sample.authorUserId,
          authorDisplayName: _sample.authorDisplayName,
          authorRankTitle: _sample.authorRankTitle,
          body: _sample.body,
          rating: _sample.rating,
          status: _sample.status,
          createdAt: _sample.createdAt,
          media: _sample.media,
          replyTo: _sample.replyTo,
        ),
      ],
      total: 1,
      averageRating: 4.1,
      ratingCount: 1,
    );
  }

  @override
  Future<RouteReview> submit({
    required String routeId,
    required String body,
    required int rating,
    List<String> imagePaths = const [],
    String? replyToReviewId,
  }) async {
    return RouteReview(
      id: 'mock-new',
      routeId: routeId,
      authorUserId: 'me',
      authorDisplayName: 'Вы',
      authorRankTitle: 'Новичок',
      body: body,
      rating: rating,
      status: 'pending_review',
      createdAt: DateTime.now().toUtc(),
      media: [
        for (var index = 0; index < imagePaths.length; index++)
          RouteReviewMedia(
            id: 'mock-media-$index',
            url: imagePaths[index],
            sortOrder: index,
          ),
      ],
      replyTo: replyToReviewId == null
          ? null
          : RouteReviewReply(
              reviewId: replyToReviewId,
              authorUserId: 'u1',
              authorDisplayName: 'Никита',
              body: _sample.body,
            ),
    );
  }

  @override
  Future<void> delete({
    required String routeId,
    required String reviewId,
  }) async {}

  @override
  Future<void> deleteMedia({
    required String routeId,
    required String reviewId,
    required String mediaId,
  }) async {}

  @override
  Future<List<RouteReview>> listMine() async => const [];
}

final routeReviewsRepositoryProvider = Provider<RouteReviewsRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return MockRouteReviewsRepository();
  }
  return ApiRouteReviewsRepository(ref.watch(dioProvider));
});
