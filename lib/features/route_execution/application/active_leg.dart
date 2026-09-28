import 'package:tourism_mobile/features/route_execution/application/antifraud_hints.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

/// The stretch being walked right now (FRONTEND-22): from the last marked
/// stop to the first unmarked one.
///
/// Same rule as the map's accent line: none before the first mark, none once
/// every stop is marked, none while the run is paused or over.
class ActiveLegInfo {
  const ActiveLegInfo({required this.from, required this.to});

  final RouteExecutionStop from;
  final RouteExecutionStop to;

  /// «участок 2–3» by the numbers the stop list shows. No arrow: Rubik has
  /// no glyph for it.
  String get title => 'участок ${from.position}–${to.position}';

  /// «1,2 км • ≈ 25 мин», or just the length when there is no estimate.
  String? get meta =>
      formatLegLabel(to.legDistanceMeters, to.legEstimateSeconds) ??
      (to.legDistanceMeters == null
          ? null
          : formatStopDistance(to.legDistanceMeters!));
}

ActiveLegInfo? activeLegInfo(RouteExecution execution) {
  if (!execution.isActive) return null;
  final stops = [...execution.stops]
    ..sort((a, b) => a.position.compareTo(b.position));
  final nextIndex = stops.indexWhere((stop) => !stop.isCompleted);
  if (nextIndex <= 0) return null;
  final from = stops[nextIndex - 1];
  if (!from.isCompleted) return null;
  return ActiveLegInfo(from: from, to: stops[nextIndex]);
}
