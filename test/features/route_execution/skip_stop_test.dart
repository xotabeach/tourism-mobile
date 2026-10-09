import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_execution/application/active_leg.dart';
import 'package:tourism_mobile/features/route_execution/application/local_run_changes.dart';
import 'package:tourism_mobile/features/route_execution/application/run_outcome.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/route_execution_summary_screen.dart';
import 'package:tourism_mobile/features/routes/data/route_reviews_repository.dart';

RouteExecution _run({
  List<String?> skipReasons = const [null, null, null, null],
  int marked = 1,
  bool counted = true,
  int? share,
  RouteExecutionStatus status = RouteExecutionStatus.active,
  String? routeId = 'route-1',
}) {
  final started = DateTime.utc(2026, 10, 9, 8);
  return RouteExecution.fromJson({
    'id': 'run-1',
    'route_id': routeId,
    'route_name': 'Маршрут',
    'status': status.name,
    'started_at': started.toIso8601String(),
    'completed_at': status == RouteExecutionStatus.completed
        ? started.add(const Duration(hours: 2)).toIso8601String()
        : null,
    'total_stops': 4,
    'completed_stops': marked,
    'required_stops': 4,
    'completed_required_stops': marked,
    'skipped_required_stops': skipReasons.whereType<String>().length,
    'counted': counted,
    'completed_share_percent': share,
    'counted_threshold_percent': 70,
    'awarded_points': 40,
    'points_status': 'awarded',
    'stops': [
      for (var i = 0; i < 4; i++)
        {
          'id': 's$i',
          'position': i + 1,
          'place_name': 'Точка ${i + 1}',
          'is_optional': false,
          'completed_at': i < marked
              ? started.add(Duration(minutes: 10 * (i + 1))).toIso8601String()
              : null,
          'skipped_at': skipReasons[i] == null
              ? null
              : started.add(const Duration(minutes: 50)).toIso8601String(),
          'skip_reason': skipReasons[i],
        },
    ],
  });
}

void main() {
  test('a skipped stop is read with its reason and survives the cache', () {
    final run = _run(skipReasons: [null, 'closed', 'no_time', null]);

    expect(run.skippedRequiredStops, 2);
    expect(run.stops[1].isSkipped, isTrue);
    expect(run.stops[1].skipReason, StopSkipReason.closed);
    expect(run.stops[2].skipReason, StopSkipReason.noTime);
    expect(run.stops[0].isSkipped, isFalse);
    expect(run.hasSkippedStops, isTrue);

    final cached = RouteExecution.fromJson(run.toJson());
    expect(cached.stops[1].skipReason, StopSkipReason.closed);
    expect(cached.skippedRequiredStops, 2);
    expect(cached.countedThresholdPercent, 70);
  });

  test('an unknown reason from a newer server still reads as skipped', () {
    final run = _run(skipReasons: [null, 'weather', null, null]);

    expect(run.stops[1].isSkipped, isTrue);
    expect(run.stops[1].skipReason, isNull);
  });

  test('a run from an older server counts and has nothing skipped', () {
    final run = RouteExecution.fromJson({
      'id': 'run-1',
      'status': 'completed',
      'started_at': '2026-10-09T08:00:00Z',
      'stops': <Object>[],
    });

    expect(run.counted, isTrue);
    expect(run.skippedRequiredStops, 0);
    expect(run.completedSharePercent, isNull);
    expect(RunOutcome.of(run).note, isNull);
  });

  test('skipping locally counts the stop and a mark replaces the skip', () {
    final at = DateTime.utc(2026, 10, 9, 9);
    final skipped = skipStopLocally(_run(), 's1', StopSkipReason.hard, at);

    expect(skipped.stops[1].isSkipped, isTrue);
    expect(skipped.skippedRequiredStops, 1);
    expect(skipped.completedStops, 1);
    // A marked stop is never turned into a skipped one.
    expect(
      skipStopLocally(
        skipped,
        's0',
        StopSkipReason.hard,
        at,
      ).stops[0].isCompleted,
      isTrue,
    );

    final marked = completeStopLocally(skipped, 's1', at);
    expect(marked.stops[1].isCompleted, isTrue);
    expect(marked.stops[1].isSkipped, isFalse);
    expect(marked.skippedRequiredStops, 0);

    final back = unskipStopLocally(skipped, 's1');
    expect(back.stops[1].isSettled, isFalse);
    expect(back.skippedRequiredStops, 0);
  });

  test('the leg in progress starts after a skipped stop', () {
    final run = _run(skipReasons: [null, 'no_time', null, null]);

    final leg = activeLegInfo(run);

    expect(leg?.from.id, 's1');
    expect(leg?.to.id, 's2');
  });

  group('run outcome', () {
    test('a run below the threshold is partial and says why', () {
      final outcome = RunOutcome.of(
        _run(
          skipReasons: [null, null, 'no_time', 'no_time'],
          marked: 2,
          counted: false,
          share: 50,
          status: RouteExecutionStatus.completed,
        ),
      );

      expect(outcome.counted, isFalse);
      expect(outcome.title, 'Маршрут пройден частично');
      expect(outcome.note, contains('Отмечено 50% обязательных точек'));
      expect(outcome.note, contains('от 70%'));
      expect(outcome.note, contains('за пройденные участки'));
    });

    test('a run above the threshold counts even with a skip', () {
      final outcome = RunOutcome.of(
        _run(
          skipReasons: [null, null, null, 'closed'],
          marked: 3,
          share: 75,
          status: RouteExecutionStatus.completed,
        ),
      );

      expect(outcome.counted, isTrue);
      expect(outcome.title, 'Маршрут пройден!');
      expect(outcome.note, contains('75%'));
      expect(outcome.note, contains('маршрут засчитан'));
    });

    test('a run finished offline works the share out itself', () {
      final outcome = RunOutcome.of(
        _run(
          skipReasons: [null, null, 'hard', 'hard'],
          marked: 2,
          status: RouteExecutionStatus.completed,
        ),
      );

      expect(outcome.counted, isFalse);
      expect(outcome.note, contains('Отмечено 50%'));
    });
  });

  testWidgets('the summary of a partial run says it does not count', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RouteExecutionSummaryScreen(
            execution: _run(
              skipReasons: [null, null, 'no_time', 'no_time'],
              marked: 2,
              counted: false,
              share: 50,
              status: RouteExecutionStatus.completed,
              // No route to load: the card is what is under test.
              routeId: null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Маршрут пройден частично'), findsOneWidget);
    expect(find.text('Маршрут пройден!'), findsNothing);
    expect(find.textContaining('в зачёт идёт от 70%'), findsOneWidget);
    expect(find.text('+40 ТП'), findsOneWidget);
  });

  test('a review knows its author walked only a part of the route', () {
    Map<String, dynamic> review(Object? walk, {bool completed = false}) => {
      'id': 'r1',
      'route_id': 'route-1',
      'author_user_id': 'u1',
      'body': 'Красиво',
      'rating': 5,
      'created_at': '2026-10-09T08:00:00Z',
      'author_completed_route': completed,
      'author_walk': walk,
    };

    expect(
      RouteReview.fromJson(review('partial')).authorWalkedPartially,
      isTrue,
    );
    final full = RouteReview.fromJson(review('full', completed: true));
    expect(full.authorWalkedPartially, isFalse);
    expect(full.authorCompletedRoute, isTrue);
    expect(RouteReview.fromJson(review(null)).authorWalkedPartially, isFalse);
  });
}
