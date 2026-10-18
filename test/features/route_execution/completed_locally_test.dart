import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_execution/application/local_run_changes.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

void main() {
  test('finished offline, open stops become «Не дошёл» as on the server', () {
    // FRONTEND-91 mirrors BACKEND-75: every required stop still open, and an
    // optional one past the last stop reached; an optional one before it was
    // walked past and stays as it is.
    final at = DateTime.utc(2026, 10, 18, 16, 46);
    final run = RouteExecution(
      id: 'run-1',
      routeId: 'route-1',
      routeName: 'Выше облаков',
      status: RouteExecutionStatus.active,
      startedAt: DateTime.utc(2026, 10, 14, 17),
      totalStops: 5,
      completedStops: 1,
      requiredStops: 3,
      completedRequiredStops: 1,
      stops: [
        for (final (position, optional, marked) in [
          (1, false, false),
          (2, true, false),
          (3, false, true),
          (4, true, false),
          (5, false, false),
        ])
          RouteExecutionStop(
            id: 's$position',
            position: position,
            placeName: 'Точка $position',
            isOptional: optional,
            completedAt: marked ? at : null,
          ),
      ],
    );
    final done = completedLocally(run, at);
    expect(done.status, RouteExecutionStatus.completed);
    expect(
      [for (final stop in done.stops) stop.skipReason],
      [
        StopSkipReason.notReached,
        null,
        null,
        StopSkipReason.notReached,
        StopSkipReason.notReached,
      ],
    );
    expect(done.skippedRequiredStops, 2);
  });
}
