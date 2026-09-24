import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/route_execution_screen.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

Map<String, dynamic> _run({
  int? planned,
  int? current,
  bool? nightPaused,
  bool? endedEarly,
}) => {
  'id': 'e1',
  'route_name': 'Большой круг',
  'status': 'paused',
  'started_at': '2026-09-20T07:00:00Z',
  'total_stops': 5,
  'completed_stops': 2,
  'required_stops': 5,
  'completed_required_stops': 2,
  'stops': <dynamic>[],
  'planned_days': ?planned,
  'current_day': ?current,
  'night_paused': ?nightPaused,
  'ended_early': ?endedEarly,
};

void main() {
  test('a run reads its days and keeps them for offline', () {
    final run = RouteExecution.fromJson(
      _run(planned: 3, current: 2, nightPaused: true),
    );
    expect((run.plannedDays, run.currentDay, run.nightPaused), (3, 2, true));
    expect(run.isMultiDay, isTrue);
    final again = RouteExecution.fromJson(run.toJson());
    expect(
      (again.plannedDays, again.currentDay, again.nightPaused),
      (3, 2, true),
    );
  });

  test('an older server means a one-day run', () {
    final run = RouteExecution.fromJson(_run());
    expect((run.plannedDays, run.currentDay, run.nightPaused), (1, 1, false));
    expect(run.isMultiDay, isFalse);
    expect(run.endedEarly, isFalse);
  });

  test('the day label says when the walker takes longer than planned', () {
    expect(
      dayOfRunLabel(RouteExecution.fromJson(_run(planned: 3, current: 2))),
      'День 2 из 3',
    );
    expect(
      dayOfRunLabel(RouteExecution.fromJson(_run(planned: 4, current: 5))),
      'День 5 (по плану 4)',
    );
  });

  test('route detail reads its days with the overnight note', () {
    final route = RouteDetail.fromJson({
      'id': 'r1',
      'name': 'Большой круг',
      'slug': 'krug',
      'short_description': null,
      'stops_count': 3,
      'description': null,
      'stops': <dynamic>[],
      'days': [
        {
          'day_index': 1,
          'first_stop_id': 's1',
          'last_stop_id': 's2',
          'overnight_note': 'Ночлег в районе: Судак',
        },
        {
          'day_index': 2,
          'first_stop_id': 's3',
          'last_stop_id': 's3',
          'overloaded': true,
        },
      ],
    });
    expect(route.days.map((d) => d.dayIndex), [1, 2]);
    expect(route.days.first.overnightNote, 'Ночлег в районе: Судак');
    expect(route.days.last.overloaded, isTrue);
    final again = RouteDetail.fromJson(route.toJson());
    expect(again.days.last.lastStopId, 's3');
    expect(again.days.first.boundarySource, 'auto');
  });
}
