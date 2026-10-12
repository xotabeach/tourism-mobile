import 'package:tourism_mobile/features/route_execution/application/antifraud_hints.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

/// Used when the server sent no thresholds (anti-fraud not enforcing): the
/// same distances it would apply.
const defaultNearbyToleranceMeters = 150;
const defaultNearbyMinAccuracyMeters = 100;

/// The stop to offer «вы рядом, отметить?» for, or null.
///
/// Only while the app is open: it reads the fix the screen already has, no
/// background location. The nearest stop that is neither marked nor skipped
/// and lies within the anti-fraud tolerance is offered, so a mark made from
/// the hint is one the server would accept by distance. A stale or coarse
/// fix offers nothing: a wrong hint is worse than none.
RouteExecutionStop? nearbyStopToMark({
  required RouteExecution execution,
  required PositionFix? fix,
  required DateTime now,
  Set<String> dismissed = const {},
}) {
  if (!execution.isActive || fix == null || !fix.isFresh(now)) return null;
  final thresholds = execution.antifraud;
  final tolerance =
      thresholds?.gpsToleranceMeters ?? defaultNearbyToleranceMeters;
  final minAccuracy =
      thresholds?.gpsMinAccuracyMeters ?? defaultNearbyMinAccuracyMeters;
  if (fix.accuracyMeters > minAccuracy) return null;
  RouteExecutionStop? nearest;
  var nearestDistance = double.infinity;
  for (final stop in execution.stops) {
    final lat = stop.lat;
    final lng = stop.lng;
    if (stop.isSettled || lat == null || lng == null) continue;
    final distance = distanceMeters(fix.lat, fix.lng, lat, lng);
    if (distance <= tolerance && distance < nearestDistance) {
      nearest = stop;
      nearestDistance = distance;
    }
  }
  if (nearest == null || dismissed.contains(nearest.id)) return null;
  return nearest;
}
