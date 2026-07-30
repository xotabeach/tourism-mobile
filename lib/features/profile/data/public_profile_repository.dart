import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

class PublicUserProfile {
  const PublicUserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.coverUrl,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? coverUrl;

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) {
    return PublicUserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      coverUrl: json['cover_url'] as String?,
    );
  }
}

class PublicProfileBundle {
  const PublicProfileBundle({
    required this.user,
    required this.routes,
  });

  final PublicUserProfile user;
  final List<RouteSummary> routes;
}

abstract class PublicProfileRepository {
  Future<PublicProfileBundle> fetch(String userId);
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
}
