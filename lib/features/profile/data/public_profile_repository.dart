import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

class PublicUserProfile {
  const PublicUserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.coverUrl,
    this.travelPoints = 0,
    this.rankSlug = 'novice',
    this.rankTitle = 'Новичок',
    this.nextRankPoints = 1000,
    this.leaderboardPlace = 0,
    this.likedByMe = false,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? coverUrl;
  final int travelPoints;
  final String rankSlug;
  final String rankTitle;
  final int nextRankPoints;
  final int leaderboardPlace;
  final bool likedByMe;

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) {
    return PublicUserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      travelPoints: (json['travel_points'] as num?)?.toInt() ?? 0,
      rankSlug: json['rank_slug'] as String? ?? 'novice',
      rankTitle: json['rank_title'] as String? ?? 'Новичок',
      nextRankPoints: (json['next_rank_points'] as num?)?.toInt() ?? 1000,
      leaderboardPlace: (json['leaderboard_place'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] as bool? ?? false,
    );
  }
}

class PublicProfileBundle {
  const PublicProfileBundle({required this.user, required this.routes});

  final PublicUserProfile user;
  final List<RouteSummary> routes;
}

abstract class PublicProfileRepository {
  Future<PublicProfileBundle> fetch(String userId);
  Future<List<PublicUserProfile>> search(String query, {int limit = 8});
  Future<List<PublicUserProfile>> subscriptions({int limit = 50});
  Future<List<PublicUserProfile>> leaderboard({int limit = 50, int offset = 0});
  Future<void> like(String userId);
  Future<void> unlike(String userId);
}

class ApiPublicProfileRepository implements PublicProfileRepository {
  ApiPublicProfileRepository(this._dio);

  final Dio _dio;

  @override
  Future<PublicProfileBundle> fetch(String userId) {
    return guardApiCall(() async {
      final userResponse = await _dio.get<Map<String, dynamic>>(
        '/api/v1/users/$userId',
      );
      final routesResponse = await _dio.get<Map<String, dynamic>>(
        '/api/v1/users/$userId/routes',
        queryParameters: const {'limit': 20, 'offset': 0},
      );
      final page = RouteListPage.fromJson(routesResponse.data!);
      return PublicProfileBundle(
        user: PublicUserProfile.fromJson(userResponse.data!),
        routes: page.items,
      );
    });
  }

  @override
  Future<List<PublicUserProfile>> search(String query, {int limit = 8}) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/users/search',
        queryParameters: {'q': query, 'limit': limit},
      );
      final items = response.data?['items'] as List<dynamic>? ?? const [];
      return items
          .map(
            (item) => PublicUserProfile.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    });
  }

  @override
  Future<List<PublicUserProfile>> subscriptions({int limit = 50}) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/users/subscriptions',
        queryParameters: {'limit': limit},
      );
      final items = response.data?['items'] as List<dynamic>? ?? const [];
      return items
          .map(
            (item) => PublicUserProfile.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    });
  }

  @override
  Future<List<PublicUserProfile>> leaderboard({
    int limit = 50,
    int offset = 0,
  }) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/users/leaderboard',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final items = response.data?['items'] as List<dynamic>? ?? const [];
      return items
          .map(
            (item) => PublicUserProfile.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    });
  }

  @override
  Future<void> like(String userId) {
    return guardApiCall(() async {
      await _dio.put<void>('/api/v1/users/$userId/like');
    });
  }

  @override
  Future<void> unlike(String userId) {
    return guardApiCall(() async {
      await _dio.delete<void>('/api/v1/users/$userId/like');
    });
  }
}
