import 'dart:math' as math;

import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

/// Client-side hints mirroring the server's anti-fraud rules.
///
/// These only decide whether to ask the person "are you sure?" before a mark
/// is sent. The server stays the judge; nothing here is a security control.

enum PaceHint { ok, tooFast, skipped }

enum AheadHint { ahead, atOrBehind, unknown }

/// A device position with the accuracy the platform reported for it.
class PositionFix {
  const PositionFix({
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
    required this.takenAt,
  });

  final double lat;
  final double lng;
  final double accuracyMeters;
  final DateTime takenAt;

  bool isFresh(DateTime now, {Duration maxAge = const Duration(seconds: 60)}) =>
      now.difference(takenAt) <= maxAge;
}

double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dPhi = (lat2 - lat1) * math.pi / 180;
  final dLambda = (lng2 - lng1) * math.pi / 180;
  final a =
      math.pow(math.sin(dPhi / 2), 2) +
      math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(dLambda / 2), 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(a)));
}

/// Where the person is relative to the stop they are about to mark.
///
/// Same rule as the server: find the route stop nearest to the fix inside the
/// tolerance; a mark for a stop *after* it is "ahead", the same stop or an
/// earlier one is fine. Poor accuracy, a stale fix or nothing nearby is
/// "unknown" and never triggers a prompt. Order is the stop's position in the
/// route, optional stops included.
AheadHint evaluateAhead({
  required PositionFix? fix,
  required List<RouteExecutionStop> stops,
  required RouteExecutionStop marked,
  required RouteExecutionAntiFraud thresholds,
  required DateTime now,
}) {
  if (fix == null || !fix.isFresh(now)) return AheadHint.unknown;
  if (fix.accuracyMeters > thresholds.gpsMinAccuracyMeters) {
    return AheadHint.unknown;
  }
  RouteExecutionStop? nearest;
  var nearestDistance = double.infinity;
  for (final stop in stops) {
    final lat = stop.lat;
    final lng = stop.lng;
    if (lat == null || lng == null) continue;
    final distance = distanceMeters(fix.lat, fix.lng, lat, lng);
    if (distance < nearestDistance ||
        (distance == nearestDistance &&
            nearest != null &&
            stop.position < nearest.position)) {
      nearest = stop;
      nearestDistance = distance;
    }
  }
  if (nearest == null || nearestDistance > thresholds.gpsToleranceMeters) {
    return AheadHint.unknown;
  }
  return marked.position > nearest.position
      ? AheadHint.ahead
      : AheadHint.atOrBehind;
}

/// Whether a mark made now covers its leg suspiciously fast.
///
/// [lastMarkAt] is when the previous stop was marked (null for the first
/// stop, which has no leg). [pausedDeltaSeconds] is pause time added since
/// that mark; when unknown pass 0 - the error then leans towards "no prompt".
PaceHint evaluateLegPace({
  required RouteExecutionStop stop,
  required DateTime? lastMarkAt,
  required int pausedDeltaSeconds,
  required DateTime now,
  required bool enforcing,
  AheadHint gps = AheadHint.unknown,
}) {
  final threshold = stop.paceWarnBelowSeconds;
  if (!enforcing || threshold == null || lastMarkAt == null) {
    return PaceHint.skipped;
  }
  // The server skips the pace rule when the position says "on site or past".
  if (gps == AheadHint.atOrBehind) return PaceHint.skipped;
  final elapsed = now.difference(lastMarkAt).inSeconds - pausedDeltaSeconds;
  return elapsed < threshold ? PaceHint.tooFast : PaceHint.ok;
}

/// "3,5 км · ≈ 40 мин" for a leg row, or null when there is nothing worth
/// showing (no estimate, or a leg of about two minutes or less).
String? formatLegLabel(int? distanceMeters, int? estimateSeconds) {
  if (estimateSeconds == null || estimateSeconds < 120) return null;
  final minutes = (estimateSeconds / 60 / 5).round() * 5;
  final time = minutes >= 60
      ? _hours(minutes)
      : '≈ ${math.max(minutes, 5)} мин';
  final distance = distanceMeters == null ? null : _distance(distanceMeters);
  return distance == null ? time : '$distance · $time';
}

String _hours(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '≈ $hours ч' : '≈ $hours ч $rest мин';
}

String _distance(int meters) {
  if (meters < 1000) return '$meters м';
  final km = (meters / 100).round() / 10;
  final text = km == km.roundToDouble()
      ? km.toInt().toString()
      : km.toStringAsFixed(1).replaceAll('.', ',');
  return '$text км';
}

/// The part of [line] between two stops, cut by walking the vertices in
/// order so a loop route (start = finish) still yields the right stretch.
///
/// The search is monotonic: each stop's nearest vertex is looked for at or
/// after the previous stop's vertex, never before it.
List<({double lat, double lng})> sliceLegPolyline(
  List<({double lat, double lng})> line, {
  required List<RouteExecutionStop> stops,
  required RouteExecutionStop from,
  required RouteExecutionStop to,
}) {
  if (line.length < 2) return const [];
  final ordered = [
    for (final stop in stops)
      if (stop.lat != null && stop.lng != null) stop,
  ]..sort((a, b) => a.position.compareTo(b.position));
  var cursor = 0;
  int? fromIndex;
  int? toIndex;
  for (final stop in ordered) {
    var best = cursor;
    var bestDistance = double.infinity;
    for (var i = cursor; i < line.length; i++) {
      final d = distanceMeters(stop.lat!, stop.lng!, line[i].lat, line[i].lng);
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    cursor = best;
    if (stop.id == from.id) fromIndex = best;
    if (stop.id == to.id) toIndex = best;
  }
  if (fromIndex == null || toIndex == null || toIndex <= fromIndex) {
    return const [];
  }
  return line.sublist(fromIndex, toIndex + 1);
}
