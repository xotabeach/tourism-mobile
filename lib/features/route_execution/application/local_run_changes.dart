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

/// A run finished on the phone while offline, the way the server will
/// finish it (BACKEND-75): every stop still open is «Не дошёл», except an
/// optional one before the last stop reached, which was walked past.
RouteExecution completedLocally(RouteExecution execution, DateTime at) {
  final reached = execution.stops
      .where(
        (stop) => stop.isCompleted || stop.skipReason == StopSkipReason.closed,
      )
      .map((stop) => stop.position)
      .fold(0, (a, b) => a > b ? a : b);
  return _withStops(execution, [
    for (final stop in execution.stops)
      stop.isSettled || (stop.isOptional && stop.position < reached)
          ? stop
          : stop.skipped(StopSkipReason.notReached, at),
  ]).copyWith(status: RouteExecutionStatus.completed, completedAt: at);
}

RouteExecution completeStopLocally(
  RouteExecution execution,
  String stopId,
  DateTime completedAt,
) => _withStops(execution, [
  for (final stop in execution.stops)
    stop.id == stopId && !stop.isCompleted
        ? stop.copyWith(completedAt: completedAt)
        : stop,
]);

RouteExecution uncompleteStopLocally(RouteExecution execution, String stopId) =>
    _withStops(execution, [
      for (final stop in execution.stops)
        stop.id == stopId ? stop.withoutCompletion() : stop,
    ]);

/// A stop passed by before the server knows: a marked stop stays marked.
RouteExecution skipStopLocally(
  RouteExecution execution,
  String stopId,
  StopSkipReason reason,
  DateTime at,
) => _withStops(execution, [
  for (final stop in execution.stops)
    stop.id == stopId && !stop.isCompleted ? stop.skipped(reason, at) : stop,
]);

RouteExecution unskipStopLocally(RouteExecution execution, String stopId) =>
    _withStops(execution, [
      for (final stop in execution.stops)
        stop.id == stopId ? stop.withoutSkip() : stop,
    ]);

RouteExecution _withStops(
  RouteExecution execution,
  List<RouteExecutionStop> stops,
) => execution.copyWith(
  stops: stops,
  completedStops: stops.where((stop) => stop.isCompleted).length,
  completedRequiredStops: stops
      .where((stop) => stop.isCompleted && !stop.isOptional)
      .length,
  skippedRequiredStops: stops
      .where((stop) => stop.isSkipped && !stop.isOptional)
      .length,
);

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
