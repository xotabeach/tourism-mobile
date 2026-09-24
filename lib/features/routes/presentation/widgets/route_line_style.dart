import 'dart:ui';

import 'package:tourism_mobile/features/routes/domain/route.dart';

/// Every spelling of walking the backend has stored for a route
/// (spec 14, «Словарь способов»). Bicycles were never routed and are walked.
const _walkingModes = {
  'walk',
  'walking',
  'pedestrian',
  'foot',
  'hiking',
  'bicycle',
  'bike',
  'cycling',
};

/// Whether a route with this `transport_mode` is walked, so its line is
/// drawn dashed like on the server's map image (spec 14, D23). A missing
/// mode is walking, as on the backend.
bool isWalkingMode(String? transportMode) {
  final mode = transportMode?.trim().toLowerCase();
  return mode == null || mode.isEmpty || _walkingModes.contains(mode);
}

/// [source] cut into dashes that run on across its corners. Lengths are in
/// logical pixels; the server draws 10 on, 7 off at the same line width.
Path dashedPath(Path source, {double dash = 10, double gap = 7}) {
  final dashed = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = (distance + dash).clamp(0, metric.length).toDouble();
      dashed.addPath(metric.extractPath(distance, end), Offset.zero);
      distance = end + gap;
    }
  }
  return dashed;
}

/// How a leg is travelled, when it is more than one plain way:
/// «на машине 3,3 км · пешком 1,4 км от парковки». Null for a leg walked or
/// driven all the way, where the plain leg length already says it all.
String? legTravelSummary(List<RouteSegment> leg) {
  final mixed =
      leg.any((segment) => segment.role != 'main') ||
      leg.map((segment) => segment.mode).toSet().length > 1;
  if (!mixed) return null;
  final parts = [
    for (final segment in leg)
      if (segment.distanceMeters case final meters?)
        '${_modeWords(segment.mode)} ${_km(meters)}${_roleTail(segment.role)}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

String _modeWords(String mode) => switch (mode) {
  'walk' => 'пешком',
  'car' => 'на машине',
  'cable_car' => 'на канатной дороге',
  'ferry' => 'на пароме',
  'train' => 'на электричке',
  _ => 'на транспорте',
};

String _roleTail(String role) => switch (role) {
  'approach' => ' от парковки',
  'return' => ' обратно к машине',
  _ => '',
};

String _km(int meters) {
  if (meters < 1000) return '$meters м';
  final km = (meters / 100).round() / 10;
  final text = km == km.roundToDouble()
      ? km.toInt().toString()
      : km.toStringAsFixed(1).replaceAll('.', ',');
  return '$text км';
}
