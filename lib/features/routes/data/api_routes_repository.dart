import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/domain/routes_repository.dart';

class ApiRoutesRepository implements RoutesRepository {
  ApiRoutesRepository(this._dio);

  final Dio _dio;

  @override
  Future<RouteListPage> listRoutes({
    String? regionSlug,
    int limit = 50,
    RouteCatalogSort sort = RouteCatalogSort.defaultOrder,
  }) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/routes',
        queryParameters: {
          'region_slug': ?regionSlug,
          'limit': limit,
          'sort': sort.apiValue,
        },
      );
      return RouteListPage.fromJson(response.data!);
    });
  }

  @override
  Future<RouteListPage> listMyRoutes() {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/routes/mine',
        queryParameters: {'limit': 100},
      );
      return RouteListPage.fromJson(response.data!);
    });
  }

  @override
  Future<RouteDetail> getRoute(String id) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/routes/$id',
      );
      return RouteDetail.fromJson(response.data!);
    });
  }

  @override
  Future<RouteDetail> getMyRoute(String id) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/routes/mine/$id',
      );
      return RouteDetail.fromJson(response.data!);
    });
  }
}
