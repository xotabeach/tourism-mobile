import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/domain/routes_repository.dart';

class ApiRoutesRepository implements RoutesRepository {
  ApiRoutesRepository(this._dio);

  final Dio _dio;

  @override
  Future<RouteListPage> listRoutes({String? regionSlug}) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/routes',
        queryParameters: {'region_slug': ?regionSlug, 'limit': 50},
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
}
