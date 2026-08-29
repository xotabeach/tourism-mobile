import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

abstract interface class RouteExecutionRepository {
  Future<List<RouteExecution>> list({int limit = 20, int offset = 0});

  Future<RouteExecution?> getActive();

  Future<RouteExecution> start(String routeId);

  /// [clientEventId] makes a retry safe and [occurredAt] reports when the
  /// action really happened, which differs from now for a queued offline tap.
  Future<RouteExecution> completeStop(
    String executionId,
    String stopId, {
    String? clientEventId,
    DateTime? occurredAt,
  });

  Future<RouteExecution> complete(
    String executionId, {
    String? clientEventId,
    DateTime? occurredAt,
  });

  Future<RouteExecution> cancel(
    String executionId, {
    String? clientEventId,
    DateTime? occurredAt,
  });
}
