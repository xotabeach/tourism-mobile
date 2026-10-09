import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

Set<String> undeliveredKeys(RouteExecution? execution) => {
  for (final stop in execution?.stops ?? const <RouteExecutionStop>[])
    if (stop.undelivered && !stop.isCompleted) stop.routeStopId ?? stop.id,
};

/// The stop whose mark can be taken back: the latest one marked, so legs
/// and pace keep following the order the stops were really reached in.
String? lastMarkedStopId(RouteExecution execution) {
  RouteExecutionStop? latest;
  for (final stop in execution.stops) {
    final at = stop.completedAt;
    if (at == null) continue;
    if (latest == null || at.isAfter(latest.completedAt!)) latest = stop;
  }
  return latest?.id;
}

RouteExecution completeStopLocally(
  RouteExecution execution,
  String stopId,
  DateTime completedAt,
) {
  final stops = [
    for (final stop in execution.stops)
      stop.id == stopId && !stop.isCompleted
          ? stop.copyWith(completedAt: completedAt)
          : stop,
  ];
  final completed = stops.where((stop) => stop.isCompleted).length;
  final required = stops
      .where((stop) => stop.isCompleted && !stop.isOptional)
      .length;
  return execution.copyWith(
    stops: stops,
    completedStops: completed,
    completedRequiredStops: required,
  );
}

RouteExecution uncompleteStopLocally(RouteExecution execution, String stopId) {
  final stops = [
    for (final stop in execution.stops)
      stop.id == stopId ? stop.withoutCompletion() : stop,
  ];
  return execution.copyWith(
    stops: stops,
    completedStops: stops.where((stop) => stop.isCompleted).length,
    completedRequiredStops: stops
        .where((stop) => stop.isCompleted && !stop.isOptional)
        .length,
  );
}

/// Offline pause/resume keep the timer honest until the server answers:
/// a pause freezes it, a resume folds the pause into the paused total.
RouteExecution pausedLocally(RouteExecution run, DateTime at) =>
    run.copyWith(status: RouteExecutionStatus.paused, pausedAt: at);

RouteExecution resumedLocally(RouteExecution run, DateTime at) {
  final since = run.pausedAt;
  return run.copyWith(
    status: RouteExecutionStatus.active,
    clearPausedAt: true,
    lastActivityAt: at,
    pausedDurationSeconds: since == null
        ? null
        : run.pausedDurationSeconds + at.difference(since).inSeconds,
  );
}
