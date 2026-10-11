import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_execution/application/antifraud_hints.dart';
import 'package:tourism_mobile/features/route_execution/application/nearby_stop.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/execution_progress.dart';

final _now = DateTime.utc(2026, 10, 11, 9);

// Stops about 1.1 km apart along one meridian.
RouteExecution _run({
  RouteExecutionStatus status = RouteExecutionStatus.active,
  int marked = 1,
  String? skipped,
  RouteExecutionAntiFraud? antifraud,
}) => RouteExecution(
  id: 'run-1',
  routeName: 'Маршрут',
  status: status,
  startedAt: _now.subtract(const Duration(hours: 1)),
  totalStops: 4,
  completedStops: marked,
  requiredStops: 4,
  completedRequiredStops: marked,
  antifraud: antifraud,
  stops: [
    for (var i = 0; i < 4; i++)
      RouteExecutionStop(
        id: 's$i',
        position: i + 1,
        placeName: 'Точка ${i + 1}',
        isOptional: false,
        lat: 44.60 + i * 0.01,
        lng: 34.40,
        completedAt: i < marked ? _now : null,
        skippedAt: 's$i' == skipped ? _now : null,
        skipReason: 's$i' == skipped ? StopSkipReason.noTime : null,
      ),
  ],
);

PositionFix _fix(
  double lat, {
  double accuracy = 15,
  Duration age = Duration.zero,
}) => PositionFix(
  lat: lat,
  lng: 34.40,
  accuracyMeters: accuracy,
  takenAt: _now.subtract(age),
);

void main() {
  test('a stop within reach that is not marked yet is offered', () {
    // ~55 m from stop 2.
    final stop = nearbyStopToMark(
      execution: _run(),
      fix: _fix(44.6105),
      now: _now,
    );

    expect(stop?.id, 's1');
  });

  test('a marked or skipped stop is never offered', () {
    expect(
      nearbyStopToMark(execution: _run(), fix: _fix(44.6001), now: _now),
      isNull,
    );
    expect(
      nearbyStopToMark(
        execution: _run(skipped: 's1'),
        fix: _fix(44.6105),
        now: _now,
      ),
      isNull,
    );
  });

  test('too far, a coarse fix or a stale one offer nothing', () {
    // ~500 m from the nearest stop.
    expect(
      nearbyStopToMark(execution: _run(), fix: _fix(44.6145), now: _now),
      isNull,
    );
    expect(
      nearbyStopToMark(
        execution: _run(),
        fix: _fix(44.6105, accuracy: 400),
        now: _now,
      ),
      isNull,
    );
    expect(
      nearbyStopToMark(
        execution: _run(),
        fix: _fix(44.6105, age: const Duration(minutes: 5)),
        now: _now,
      ),
      isNull,
    );
    expect(nearbyStopToMark(execution: _run(), fix: null, now: _now), isNull);
  });

  test('the reach is the server tolerance when it sends one', () {
    // ~55 m away: inside the default 150 m, outside a strict 30 m.
    const strict = RouteExecutionAntiFraud(
      gpsToleranceMeters: 30,
      gpsMinAccuracyMeters: 50,
    );

    expect(
      nearbyStopToMark(
        execution: _run(antifraud: strict),
        fix: _fix(44.6105),
        now: _now,
      ),
      isNull,
    );
    expect(
      nearbyStopToMark(
        execution: _run(antifraud: strict),
        fix: _fix(44.6102),
        now: _now,
      )?.id,
      's1',
    );
  });

  test('a paused or finished run, and a dismissed stop, offer nothing', () {
    for (final status in [
      RouteExecutionStatus.paused,
      RouteExecutionStatus.completed,
      RouteExecutionStatus.cancelled,
    ]) {
      expect(
        nearbyStopToMark(
          execution: _run(status: status),
          fix: _fix(44.6105),
          now: _now,
        ),
        isNull,
      );
    }
    expect(
      nearbyStopToMark(
        execution: _run(),
        fix: _fix(44.6105),
        now: _now,
        dismissed: {'s1'},
      ),
      isNull,
    );
  });

  test('a later stop passed by first is offered too', () {
    // Standing at stop 4 while 2 and 3 are not marked.
    final stop = nearbyStopToMark(
      execution: _run(),
      fix: _fix(44.6301),
      now: _now,
    );

    expect(stop?.id, 's3');
  });

  testWidgets('the hint marks or steps aside', (tester) async {
    var marked = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NearbyStopHint(
            placeName: 'Ротонда',
            onMark: () => marked++,
            onDismiss: () => dismissed++,
          ),
        ),
      ),
    );

    expect(find.text('Вы рядом с точкой «Ротонда»'), findsOneWidget);
    await tester.tap(find.text('Отметить'));
    await tester.tap(find.text('Не сейчас'));
    expect((marked, dismissed), (1, 1));
  });
}
