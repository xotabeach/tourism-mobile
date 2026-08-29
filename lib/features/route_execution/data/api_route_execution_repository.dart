import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution_repository.dart';

class ApiRouteExecutionRepository implements RouteExecutionRepository {
  ApiRouteExecutionRepository(this._dio);

  final Dio _dio;

  @override
  Future<RouteExecution?> getActive() {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/route-executions/active',
      );
      final data = response.data;
      return data == null ? null : RouteExecution.fromJson(data);
    });
  }

  @override
  Future<RouteExecution> start(String routeId) {
    return _mutate(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/route-executions',
        data: {'route_id': routeId},
      ),
    );
  }

  @override
  Future<RouteExecution> completeStop(String executionId, String stopId) {
    return _mutate(
      () => _dio.put<Map<String, dynamic>>(
        '/api/v1/route-executions/$executionId/stops/$stopId/complete',
      ),
    );
  }

  @override
  Future<RouteExecution> complete(String executionId) {
    return _mutate(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/route-executions/$executionId/complete',
      ),
    );
  }

  @override
  Future<RouteExecution> cancel(String executionId) {
    return _mutate(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/route-executions/$executionId/cancel',
      ),
    );
  }

  Future<RouteExecution> _mutate(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) {
    return guardApiCall(() async {
      final response = await request();
      return RouteExecution.fromJson(response.data!);
    });
  }
}
