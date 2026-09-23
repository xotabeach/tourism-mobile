import 'dart:ui';

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
