import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/features/route_execution/application/local_run_changes.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/execution_stop_list.dart';

RouteExecution _run(Map<int, DateTime?> marks) => RouteExecution(
  id: 'run-1',
  routeId: 'route-1',
  routeName: 'Выше облаков',
  status: RouteExecutionStatus.active,
  startedAt: DateTime.utc(2026, 10, 14, 17),
  totalStops: 3,
  completedStops: marks.values.whereType<DateTime>().length,
  requiredStops: 3,
  completedRequiredStops: marks.values.whereType<DateTime>().length,
  stops: [
    for (final position in [1, 2, 3])
      RouteExecutionStop(
        id: 's$position',
        position: position,
        placeName: 'Точка $position',
        isOptional: false,
        completedAt: marks[position],
      ),
  ],
);

void main() {
  test('«Вы на N точке» names the stop marked last, not the count', () {
    // FRONTEND-93: marking 2 and then 3 used to read «Вы на 2 точке».
    final run = _run({
      2: DateTime.utc(2026, 10, 18, 16, 46, 14),
      3: DateTime.utc(2026, 10, 18, 16, 46, 16),
    });
    expect(lastMarkedPosition(run), 3);
    expect(lastMarkedPosition(_run({})), isNull);
    expect(
      lastMarkedPosition(
        _run({
          3: DateTime.utc(2026, 10, 18, 10),
          1: DateTime.utc(2026, 10, 18, 11),
        }),
      ),
      1,
    );
  });

  testWidgets('the next stop\'s ring stands out on its tinted row', (
    tester,
  ) async {
    // FRONTEND-90: the light grey ring vanished on the blue «Следующая» row.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ExecutionStopMark(
                next: true,
                done: false,
                busy: false,
                placeName: 'Караул-Оба',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final ring = tester.widget<Container>(
      find.descendant(
        of: find.byType(ExecutionStopMark),
        matching: find.byType(Container),
      ),
    );
    final border = (ring.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, AppColors.accentBlue);
    expect(border.top.width, greaterThanOrEqualTo(2));
  });
}
