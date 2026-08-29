import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution_repository.dart';

class MockRouteExecutionRepository implements RouteExecutionRepository {
  RouteExecution? _active;

  @override
  Future<RouteExecution?> getActive() async => _active;

  @override
  Future<RouteExecution> start(String routeId) async {
    final current = _active;
    if (current != null && current.isActive) return current;
    _active = RouteExecution(
      id: 'mock-execution-$routeId',
      routeId: routeId,
      routeName: 'Маршрут КрымТрип',
      status: RouteExecutionStatus.active,
      startedAt: DateTime.now(),
      totalStops: 0,
      completedStops: 0,
      requiredStops: 0,
      completedRequiredStops: 0,
      stops: const [],
    );
    return _active!;
  }

  @override
  Future<RouteExecution> completeStop(String executionId, String stopId) =>
      _requireActive();

  @override
  Future<RouteExecution> complete(String executionId) async {
    final current = await _requireActive();
    _active = RouteExecution(
      id: current.id,
      routeId: current.routeId,
      routeName: current.routeName,
      status: RouteExecutionStatus.completed,
      startedAt: current.startedAt,
      completedAt: DateTime.now(),
      totalStops: current.totalStops,
      completedStops: current.completedStops,
      requiredStops: current.requiredStops,
      completedRequiredStops: current.completedRequiredStops,
      stops: current.stops,
      routing: current.routing,
    );
    return _active!;
  }

  @override
  Future<RouteExecution> cancel(String executionId) async {
    final current = await _requireActive();
    _active = RouteExecution(
      id: current.id,
      routeId: current.routeId,
      routeName: current.routeName,
      status: RouteExecutionStatus.cancelled,
      startedAt: current.startedAt,
      cancelledAt: DateTime.now(),
      totalStops: current.totalStops,
      completedStops: current.completedStops,
      requiredStops: current.requiredStops,
      completedRequiredStops: current.completedRequiredStops,
      stops: current.stops,
      routing: current.routing,
    );
    return _active!;
  }

  Future<RouteExecution> _requireActive() async {
    final value = _active;
    if (value == null) {
      throw StateError('Нет активного маршрута');
    }
    return value;
  }
}
