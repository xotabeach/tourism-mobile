import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_execution/application/antifraud_hints.dart';
import 'package:tourism_mobile/features/route_execution/application/mark_advice.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

final _now = DateTime.utc(2026, 9, 20, 12);

RouteExecution _run({
  RouteExecutionAntiFraud? antifraud = const RouteExecutionAntiFraud(
    gpsToleranceMeters: 150,
    gpsMinAccuracyMeters: 100,
  ),
  int paused = 0,
  int? pausedAtLastMark,
  Duration sinceFirstMark = const Duration(minutes: 5),
}) => RouteExecution(
  id: 'e',
  routeName: 'M',
  status: RouteExecutionStatus.active,
  startedAt: _now.subtract(const Duration(hours: 2)),
  totalStops: 3,
  completedStops: 1,
  requiredStops: 3,
  completedRequiredStops: 1,
  antifraud: antifraud,
  pausedDurationSeconds: paused,
  pausedAtLastMarkSeconds: pausedAtLastMark,
  stops: [
    RouteExecutionStop(
      id: 's1',
      position: 1,
      placeName: 'A',
      isOptional: false,
      lat: 44.0,
      lng: 34.0,
      completedAt: _now.subtract(sinceFirstMark),
    ),
    const RouteExecutionStop(
      id: 's2',
      position: 2,
      placeName: 'B',
      isOptional: false,
      lat: 44.01,
      lng: 34.0,
      paceWarnBelowSeconds: 900,
    ),
    const RouteExecutionStop(
      id: 's3',
      position: 3,
      placeName: 'C',
      isOptional: false,
      lat: 44.02,
      lng: 34.0,
    ),
  ],
);

PositionFix _fix(double lat, {double accuracy = 15}) =>
    PositionFix(lat: lat, lng: 34.0, accuracyMeters: accuracy, takenAt: _now);

void main() {
  test('no advice at all without the server opt-in block', () {
    final run = _run(antifraud: null);
    final advice = adviseMark(
      execution: run,
      stop: run.stops[1],
      fix: _fix(44.0),
      now: _now,
    );
    expect(advice.needsConfirmation, isFalse);
  });

  test('too fast when the leg beat the threshold and there is no position', () {
    final run = _run();
    final advice = adviseMark(
      execution: run,
      stop: run.stops[1],
      fix: null,
      now: _now,
    );
    expect(advice.isTooFast, isTrue);
    expect(advice.isAhead, isFalse);
  });

  test('standing at the stop cancels the pace prompt', () {
    final run = _run();
    final advice = adviseMark(
      execution: run,
      stop: run.stops[1],
      fix: _fix(44.01),
      now: _now,
    );
    expect(advice.needsConfirmation, isFalse);
  });

  test(
    'being at an earlier stop while marking a later one is "not there yet"',
    () {
      final run = _run();
      final advice = adviseMark(
        execution: run,
        stop: run.stops[2],
        fix: _fix(44.0),
        now: _now,
      );
      expect(advice.isAhead, isTrue);
    },
  );

  test('a slow enough leg needs no prompt', () {
    final run = _run(sinceFirstMark: const Duration(minutes: 30));
    final advice = adviseMark(
      execution: run,
      stop: run.stops[1],
      fix: null,
      now: _now,
    );
    expect(advice.needsConfirmation, isFalse);
  });

  test('pause since the last mark is netted out, unknown counts as zero', () {
    final long = _run(
      sinceFirstMark: const Duration(minutes: 20),
      paused: 900,
      pausedAtLastMark: 0,
    );
    expect(pausedSinceLastMark(long), 900);
    expect(
      adviseMark(
        execution: long,
        stop: long.stops[1],
        fix: null,
        now: _now,
      ).isTooFast,
      isTrue,
    );
    final unknown = _run(paused: 900);
    expect(pausedSinceLastMark(unknown), 0);
  });

  group('positionToSend', () {
    test('sent only with opt-in, sharing on, a fresh and accurate fix', () {
      final run = _run();
      final sent = positionToSend(
        execution: run,
        fix: _fix(44.0),
        sharingEnabled: true,
        now: _now,
      );
      expect(sent?.accuracyMeters, 15);
    });

    test('withheld when any condition fails', () {
      final run = _run();
      expect(
        positionToSend(
          execution: run,
          fix: _fix(44.0),
          sharingEnabled: false,
          now: _now,
        ),
        isNull,
      );
      expect(
        positionToSend(
          execution: _run(antifraud: null),
          fix: _fix(44.0),
          sharingEnabled: true,
          now: _now,
        ),
        isNull,
      );
      expect(
        positionToSend(
          execution: run,
          fix: _fix(44.0, accuracy: 300),
          sharingEnabled: true,
          now: _now,
        ),
        isNull,
      );
      expect(
        positionToSend(
          execution: run,
          fix: _fix(44.0),
          sharingEnabled: true,
          now: _now.add(const Duration(minutes: 5)),
        ),
        isNull,
      );
    });
  });
}
