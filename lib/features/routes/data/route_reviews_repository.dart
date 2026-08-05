import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';

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
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/routes/$routeId/reviews',
        data: {'body': body, 'rating': rating},
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return RouteReview.fromJson(data);
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
    );
  }

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
