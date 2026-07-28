import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/favorites/domain/favorites_repository.dart';

final class ApiFavoritesRepository implements FavoritesRepository {
  ApiFavoritesRepository(this._dio);

  final Dio _dio;

  @override
  Future<({Set<String> placeIds, Set<String> routeIds})> list() {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/favorites',
      );
      final data = response.data ?? const <String, dynamic>{};
      final places = data['place_ids'];
      final routes = data['route_ids'];
      return (
        placeIds: {
          if (places is List)
            for (final item in places)
              if (item is String) item,
        },
        routeIds: {
          if (routes is List)
            for (final item in routes)
              if (item is String) item,
        },
      );
    });
  }

  @override
  Future<void> addRoute(String routeId) {
    return guardApiCall(() async {
      await _dio.put<void>('/api/v1/favorites/routes/$routeId');
    });
  }

  @override
  Future<void> removeRoute(String routeId) {
    return guardApiCall(() async {
      await _dio.delete<void>('/api/v1/favorites/routes/$routeId');
    });
  }

  @override
  Future<void> addPlace(String placeId) {
    return guardApiCall(() async {
      await _dio.put<void>('/api/v1/favorites/places/$placeId');
    });
  }

  @override
  Future<void> removePlace(String placeId) {
    return guardApiCall(() async {
      await _dio.delete<void>('/api/v1/favorites/places/$placeId');
    });
  }
}

final class InMemoryFavoritesRepository implements FavoritesRepository {
  final Set<String> _places = {};
  final Set<String> _routes = {};

  @override
  Future<({Set<String> placeIds, Set<String> routeIds})> list() async {
    return (
      placeIds: Set.unmodifiable(_places),
      routeIds: Set.unmodifiable(_routes),
    );
  }

  @override
  Future<void> addRoute(String routeId) async {
    _routes.add(routeId);
  }

  @override
  Future<void> removeRoute(String routeId) async {
    _routes.remove(routeId);
  }

  @override
  Future<void> addPlace(String placeId) async {
    _places.add(placeId);
  }

  @override
  Future<void> removePlace(String placeId) async {
    _places.remove(placeId);
  }
}
