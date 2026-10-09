import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

/// What the summary says about a finished run with skipped stops: whether
/// it counts as «прошёл маршрут» and why (spec 15).
class RunOutcome {
  const RunOutcome({required this.counted, required this.note});

  final bool counted;

  /// Null for an ordinary run with nothing skipped.
  final String? note;

  String get title => counted ? 'Маршрут пройден!' : 'Маршрут пройден частично';

  factory RunOutcome.of(RouteExecution execution) {
    final threshold = execution.countedThresholdPercent;
    final serverShare = execution.completedSharePercent;
    // A run finished offline has no verdict yet: the same share is worked out
    // here, and the server's answer replaces it after the sync.
    final share =
        serverShare ??
        (execution.requiredStops == 0
            ? 100
            : execution.completedRequiredStops *
                  100 ~/
                  execution.requiredStops);
    final counted = serverShare == null
        ? share >= threshold
        : execution.counted;
    if (counted && !execution.hasSkippedStops) {
      return const RunOutcome(counted: true, note: null);
    }
    const paid = 'Очки начислены за пройденные участки.';
    return RunOutcome(
      counted: counted,
      note: counted
          ? 'Отмечено $share% обязательных точек: маршрут засчитан. $paid'
          : 'Отмечено $share% обязательных точек, в зачёт идёт '
                'от $threshold%. $paid',
    );
  }
}
