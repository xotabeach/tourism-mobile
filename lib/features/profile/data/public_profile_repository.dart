import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';
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
    this.isExpert = false,
    this.expertTitle,
    this.followersCount = 0,
    this.followingCount = 0,
    this.completedRoutesCount = 0,
    this.reviewsWrittenCount = 0,
    this.totalDistanceMeters = 0,
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
  final bool isExpert;
  final String? expertTitle;
  final int followersCount;
  final int followingCount;

  /// Only populated by [PublicProfileRepository.getUser] (a single-profile
  /// fetch) — search/leaderboard/subscriptions rows reuse this same model
  /// but the backend leaves these at 0 there to avoid a per-row aggregation
  /// query, so don't render them outside the profile screen.
  final int completedRoutesCount;
  final int reviewsWrittenCount;
  final int totalDistanceMeters;

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
      isExpert: json['is_expert'] as bool? ?? false,
      expertTitle: json['expert_title'] as String?,
      followersCount: _nonNegativeCount(json['followers_count']),
      followingCount: _nonNegativeCount(json['following_count']),
      completedRoutesCount: _nonNegativeCount(json['completed_routes_count']),
      reviewsWrittenCount: _nonNegativeCount(json['reviews_written_count']),
      totalDistanceMeters: _nonNegativeCount(json['total_distance_meters']),
    );
  }
}

class PublicProfileBundle {
  const PublicProfileBundle({required this.user, required this.routes});

  final PublicUserProfile user;
  final List<RouteSummary> routes;
}

abstract class PublicProfileRepository {
  Future<PublicUserProfile> getUser(String userId);
  Future<PublicProfileBundle> fetch(String userId);
  Future<List<PublicUserProfile>> search(String query, {int limit = 8});
  Future<List<PublicUserProfile>> subscriptions({int limit = 50});
  Future<List<PublicUserProfile>> leaderboard({int limit = 50, int offset = 0});
  Future<List<ProfileAchievement>> achievements(String userId);
  Future<void> like(String userId);
  Future<void> unlike(String userId);
}

class ApiPublicProfileRepository implements PublicProfileRepository {
  ApiPublicProfileRepository(this._dio);

  final Dio _dio;

  @override
  Future<PublicUserProfile> getUser(String userId) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/users/$userId',
      );
      return PublicUserProfile.fromJson(response.data!);
    });
  }

  @override
  Future<PublicProfileBundle> fetch(String userId) {
    return guardApiCall(() async {
      final user = await getUser(userId);
      final routesResponse = await _dio.get<Map<String, dynamic>>(
        '/api/v1/users/$userId/routes',
        queryParameters: const {'limit': 20, 'offset': 0},
      );
      final page = RouteListPage.fromJson(routesResponse.data!);
      return PublicProfileBundle(user: user, routes: page.items);
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
  Future<List<ProfileAchievement>> achievements(String userId) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/users/$userId/achievements',
      );
      final items = response.data?['items'] as List<dynamic>? ?? const [];
      return [
        for (final item in items)
          if (item is Map<String, dynamic>)
            ProfileAchievement(
              id: item['id'] as String? ?? '',
              title: _boundedText(item['title'], 120),
              description: _boundedText(item['description'], 240),
              howToEarn: _boundedText(item['how_to_earn'], 240),
              iconSlug: _boundedText(item['icon_slug'], 64),
              isUnlocked: item['is_unlocked'] as bool? ?? false,
              unlockedAt: DateTime.tryParse(
                item['unlocked_at'] as String? ?? '',
              )?.toLocal(),
            ),
      ].where((item) => item.id.isNotEmpty && item.title.isNotEmpty).toList();
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

String _boundedText(Object? value, int maxChars) {
  final text = (value as String? ?? '').trim();
  if (text.length <= maxChars) {
    return text;
  }
  return text.substring(0, maxChars);
}

int _nonNegativeCount(Object? value) {
  final n = value is num ? value.toInt() : 0;
  if (n < 0) {
    return 0;
  }
  if (n > 1000000000) {
    return 1000000000;
  }
  return n;
}
