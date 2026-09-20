import 'package:tourism_mobile/features/route_execution/application/antifraud_hints.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

/// What to tell the person before a stop mark is sent.
class MarkAdvice {
  const MarkAdvice({required this.ahead, required this.pace});

  static const none = MarkAdvice(
    ahead: AheadHint.unknown,
    pace: PaceHint.skipped,
  );

  final AheadHint ahead;
  final PaceHint pace;

  bool get isAhead => ahead == AheadHint.ahead;
  bool get isTooFast => pace == PaceHint.tooFast;

  /// One shared prompt when either rule applies; "not there yet" wins the wording.
  bool get needsConfirmation => isAhead || isTooFast;
}

/// Hints exist only while the server enforces (the `antifraud` block is
/// present); in `off` and `shadow` the run carries no thresholds at all.
MarkAdvice adviseMark({
  required RouteExecution execution,
  required RouteExecutionStop stop,
  required PositionFix? fix,
  required DateTime now,
}) {
  final thresholds = execution.antifraud;
  if (thresholds == null) return MarkAdvice.none;
  final ahead = evaluateAhead(
    fix: fix,
    stops: execution.stops,
    marked: stop,
    thresholds: thresholds,
    now: now,
  );
  final pace = evaluateLegPace(
    stop: stop,
    lastMarkAt: lastMarkAt(execution),
    pausedDeltaSeconds: pausedSinceLastMark(execution),
    now: now,
    enforcing: true,
    gps: ahead,
  );
  return MarkAdvice(ahead: ahead, pace: pace);
}

/// The most recent mark on this run, or null before the first one.
DateTime? lastMarkAt(RouteExecution execution) {
  DateTime? latest;
  for (final stop in execution.stops) {
    final at = stop.completedAt;
    if (at != null && (latest == null || at.isAfter(latest))) latest = at;
  }
  return latest;
}

/// Pause time added since the last mark. Unknown counts as zero, so the error
/// leans towards "no prompt" rather than a false accusation.
int pausedSinceLastMark(RouteExecution execution) {
  final atLastMark = execution.pausedAtLastMarkSeconds;
  if (atLastMark == null) return 0;
  final delta = execution.pausedDurationSeconds - atLastMark;
  return delta < 0 ? 0 : delta;
}

/// The position to attach to a mark, or null when it must not be sent:
/// sharing off, no server opt-in, a stale fix or one that is too coarse.
MarkPosition? positionToSend({
  required RouteExecution execution,
  required PositionFix? fix,
  required bool sharingEnabled,
  required DateTime now,
}) {
  final thresholds = execution.antifraud;
  if (!sharingEnabled || thresholds == null || fix == null) return null;
  if (!fix.isFresh(now)) return null;
  if (fix.accuracyMeters > thresholds.gpsMinAccuracyMeters) return null;
  return MarkPosition(
    lat: fix.lat,
    lng: fix.lng,
    accuracyMeters: fix.accuracyMeters,
  );
}
