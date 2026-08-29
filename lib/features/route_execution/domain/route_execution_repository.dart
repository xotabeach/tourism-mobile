import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

abstract interface class RouteExecutionRepository {
  Future<RouteExecution?> getActive();

  Future<RouteExecution> start(String routeId);

  Future<RouteExecution> completeStop(String executionId, String stopId);

  Future<RouteExecution> complete(String executionId);

  Future<RouteExecution> cancel(String executionId);
}
