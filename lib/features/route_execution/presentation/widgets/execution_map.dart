import 'package:geolocator/geolocator.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/features/route_execution/application/antifraud_hints.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/map_projection.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_line_style.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_preview.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_static_map.dart';

/// Between the last marked stop and the next unmarked one; none before the
/// first mark or after the last, and none once the run is no longer active.
ActiveLeg? executionActiveLeg(RouteExecution execution, RouteDetail? route) {
  if (!execution.isActive) return null;
  final located = [
    for (final stop in execution.stops)
      if (stop.lat != null && stop.lng != null) stop,
  ]..sort((a, b) => a.position.compareTo(b.position));
  // A skipped stop is behind the walker just like a marked one.
  final nextIndex = located.indexWhere((stop) => !stop.isSettled);
  if (nextIndex <= 0) return null;
  final to = located[nextIndex];
  final from = located[nextIndex - 1];
  if (!from.isSettled) return null;
  final line = sliceLegPolyline(
    [
      for (final point
          in route?.geometry?.coordinates ?? const <RouteCoordinate>[])
        (lat: point.lat, lng: point.lng),
    ],
    stops: located,
    from: from,
    to: to,
  );
  final fromPoint = (lat: from.lat!, lng: from.lng!);
  final toPoint = (lat: to.lat!, lng: to.lng!);
  return ActiveLeg(
    // Without route geometry the leg is drawn as a straight line.
    line: line.length >= 2 ? line : [fromPoint, toPoint],
    from: fromPoint,
    to: toPoint,
    // A drive with walks is drawn part by part: walks dashed (spec 14b).
    pieces: [
      for (final segment
          in route?.segmentsTo(to.position - 1) ?? const <RouteSegment>[])
        if ((segment.geometry?.coordinates.length ?? 0) >= 2)
          (
            dashed: segment.isWalk,
            line: [
              for (final point in segment.geometry!.coordinates)
                (lat: point.lat, lng: point.lng),
            ],
          ),
    ],
  );
}

/// Whether [position] is close enough to any stop to plausibly be a real
/// fix for this run, rather than a stale cache or a simulator's default
/// location. Routes are all local (Crimea is ~300km across at most), so a
/// fix past this radius from every stop is not worth fitting the map to.
const _plausibleFixRadiusMeters = 150000;

bool isFixNearRoute(({double lat, double lng}) position, RouteDetail route) {
  for (final stop in route.stops) {
    if (stop.lat == null || stop.lng == null) {
      continue;
    }
    final distance = Geolocator.distanceBetween(
      position.lat,
      position.lng,
      stop.lat!,
      stop.lng!,
    );
    if (distance <= _plausibleFixRadiusMeters) {
      return true;
    }
  }
  return false;
}

/// How far along [route]'s geometry the walk has gotten. Null when nothing
/// is completed yet or there's no geometry to color.
///
/// Two references, whichever is further along: the last completed stop, and
/// the walker's current position. The stop alone is not enough — the first
/// stop sits on the geometry's first point, so checking it off would color
/// nothing at all; [livePosition] is what makes the line grow while walking
/// the leg towards the next stop.
double? completedRouteFraction(
  RouteExecution execution,
  RouteDetail? route,
  ({double lat, double lng})? livePosition,
) {
  final coordinates = route?.geometry?.coordinates;
  if (coordinates == null || coordinates.length < 2) {
    return null;
  }
  RouteExecutionStop? furthest;
  for (final stop in execution.stops) {
    if (!stop.isCompleted || stop.lat == null || stop.lng == null) {
      continue;
    }
    if (furthest == null || stop.position > furthest.position) {
      furthest = stop;
    }
  }
  if (furthest == null) {
    return null;
  }
  final points = [for (final c in coordinates) (lat: c.lat, lng: c.lng)];
  final reached = MapProjection.completedFraction(
    coordinates: points,
    reference: (lat: furthest.lat!, lng: furthest.lng!),
  );
  if (livePosition == null) {
    return reached;
  }
  final walked = MapProjection.completedFraction(
    coordinates: points,
    reference: livePosition,
  );
  return walked > reached ? walked : reached;
}

/// The map of a run: the walked part coloured, the leg in progress marked
/// and the walker's position when the fix is plausible.
RouteStaticMap executionMap({
  required RouteDetail route,
  required RouteExecution execution,
  required AppConfig config,
  required ({double lat, double lng})? livePosition,
}) {
  return RouteStaticMap(
    staticMapUrl: route.staticMapUrl,
    stops: route.stops,
    geometry: route.geometry,
    config: config,
    height: 342,
    footerLabel: execution.completedStops > 0
        ? 'Вы на ${execution.completedStops} точке'
        : routePointsLabel(route.stops.length),
    pillFooter: true,
    livePosition: livePosition,
    completedFraction: completedRouteFraction(execution, route, livePosition),
    completedStopPositions: {
      for (final stop in execution.stops)
        if (stop.isCompleted) stop.position,
    },
    activeLeg: executionActiveLeg(execution, route),
    dashedLine: isWalkingMode(route.transportMode),
    segments: route.segments,
  );
}
