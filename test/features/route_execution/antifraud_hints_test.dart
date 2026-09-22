import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_execution/application/antifraud_hints.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

RouteExecutionStop _stop(int position, double lat, double lng, {int? warn}) =>
    RouteExecutionStop(
      id: 's$position',
      position: position,
      placeName: 'Точка $position',
      isOptional: false,
      lat: lat,
      lng: lng,
      paceWarnBelowSeconds: warn,
    );

// ~1.1 km apart along the meridian.
final _stops = [
  _stop(1, 44.00, 34.0),
  _stop(2, 44.01, 34.0),
  _stop(3, 44.02, 34.0),
];
const _rules = RouteExecutionAntiFraud(
  gpsToleranceMeters: 150,
  gpsMinAccuracyMeters: 100,
);
final _now = DateTime.utc(2026, 9, 20, 12);

PositionFix _fix(double lat, {double accuracy = 20, DateTime? at}) =>
    PositionFix(
      lat: lat,
      lng: 34.0,
      accuracyMeters: accuracy,
      takenAt: at ?? _now,
    );

void main() {
  group('evaluateLegPace', () {
    final stop = _stop(2, 44.01, 34.0, warn: 900);

    test('too fast below the threshold', () {
      expect(
        evaluateLegPace(
          stop: stop,
          lastMarkAt: _now.subtract(const Duration(minutes: 5)),
          pausedDeltaSeconds: 0,
          now: _now,
          enforcing: true,
        ),
        PaceHint.tooFast,
      );
    });

    test('ok at or above the threshold', () {
      expect(
        evaluateLegPace(
          stop: stop,
          lastMarkAt: _now.subtract(const Duration(minutes: 15)),
          pausedDeltaSeconds: 0,
          now: _now,
          enforcing: true,
        ),
        PaceHint.ok,
      );
    });

    test('pause time is netted out, which can make a mark too fast', () {
      expect(
        evaluateLegPace(
          stop: stop,
          lastMarkAt: _now.subtract(const Duration(minutes: 20)),
          pausedDeltaSeconds: 600,
          now: _now,
          enforcing: true,
        ),
        PaceHint.tooFast,
      );
    });

    test('skipped without enforcing, threshold or a previous mark', () {
      final past = _now.subtract(const Duration(minutes: 1));
      expect(
        evaluateLegPace(
          stop: stop,
          lastMarkAt: past,
          pausedDeltaSeconds: 0,
          now: _now,
          enforcing: false,
        ),
        PaceHint.skipped,
      );
      expect(
        evaluateLegPace(
          stop: _stop(2, 44.01, 34.0),
          lastMarkAt: past,
          pausedDeltaSeconds: 0,
          now: _now,
          enforcing: true,
        ),
        PaceHint.skipped,
      );
      expect(
        evaluateLegPace(
          stop: stop,
          lastMarkAt: null,
          pausedDeltaSeconds: 0,
          now: _now,
          enforcing: true,
        ),
        PaceHint.skipped,
      );
    });

    test('skipped when the position says on site or past the stop', () {
      expect(
        evaluateLegPace(
          stop: stop,
          lastMarkAt: _now.subtract(const Duration(minutes: 1)),
          pausedDeltaSeconds: 0,
          now: _now,
          enforcing: true,
          gps: AheadHint.atOrBehind,
        ),
        PaceHint.skipped,
      );
    });
  });

  group('evaluateAhead', () {
    AheadHint run(PositionFix? fix, RouteExecutionStop marked) => evaluateAhead(
      fix: fix,
      stops: _stops,
      marked: marked,
      thresholds: _rules,
      now: _now,
    );

    test('marking a later stop than the nearest one is ahead', () {
      expect(run(_fix(44.0), _stops[2]), AheadHint.ahead);
    });

    test('the same or an earlier stop is fine', () {
      expect(run(_fix(44.01), _stops[1]), AheadHint.atOrBehind);
      expect(run(_fix(44.02), _stops[0]), AheadHint.atOrBehind);
    });

    test('nothing near, poor accuracy or a stale fix is unknown', () {
      expect(run(_fix(44.005), _stops[2]), AheadHint.unknown);
      expect(run(_fix(44.0, accuracy: 150), _stops[2]), AheadHint.unknown);
      expect(
        run(
          _fix(44.0, at: _now.subtract(const Duration(minutes: 5))),
          _stops[2],
        ),
        AheadHint.unknown,
      );
      expect(run(null, _stops[2]), AheadHint.unknown);
    });
  });

  group('formatLegLabel', () {
    test('rounds to five minutes and joins the distance', () {
      expect(formatLegLabel(3500, 2400), '3,5 км • ≈ 40 мин');
      expect(formatLegLabel(800, 780), '800 м • ≈ 15 мин');
    });

    test('long legs switch to hours', () {
      expect(formatLegLabel(9000, 3600), '9 км • ≈ 1 ч');
      expect(formatLegLabel(9000, 4500), '9 км • ≈ 1 ч 15 мин');
    });

    test('hides short or missing estimates', () {
      expect(formatLegLabel(100, 90), isNull);
      expect(formatLegLabel(100, null), isNull);
    });

    test('shows time alone without a distance', () {
      expect(formatLegLabel(null, 600), '≈ 10 мин');
    });
  });

  group('sliceLegPolyline', () {
    ({double lat, double lng}) p(double lat) => (lat: lat, lng: 34.0);

    test('cuts the stretch between two stops', () {
      final line = [for (var i = 0; i <= 20; i++) p(44.0 + i * 0.001)];
      final slice = sliceLegPolyline(
        line,
        stops: _stops,
        from: _stops[0],
        to: _stops[1],
      );
      expect(slice.first.lat, closeTo(44.0, 1e-9));
      expect(slice.last.lat, closeTo(44.01, 1e-9));
      expect(slice.length, 11);
    });

    test('a loop route yields the right stretch for the closing leg', () {
      final loopStops = [
        _stop(1, 44.0, 34.0),
        _stop(2, 44.01, 34.0),
        _stop(3, 44.0, 34.0),
      ];
      final line = [
        for (var i = 0; i <= 10; i++) p(44.0 + i * 0.001),
        for (var i = 9; i >= 0; i--) p(44.0 + i * 0.001),
      ];
      final closing = sliceLegPolyline(
        line,
        stops: loopStops,
        from: loopStops[1],
        to: loopStops[2],
      );
      expect(closing.first.lat, closeTo(44.01, 1e-9));
      expect(closing.last.lat, closeTo(44.0, 1e-9));
      expect(closing.length, 11);
    });

    test('a degenerate line yields nothing', () {
      expect(
        sliceLegPolyline(
          [p(44.0)],
          stops: _stops,
          from: _stops[0],
          to: _stops[1],
        ),
        isEmpty,
      );
    });
  });

  group('models', () {
    test('json round trip keeps every anti-fraud field', () {
      final execution = RouteExecution(
        id: 'e1',
        routeName: 'Маршрут',
        status: RouteExecutionStatus.active,
        startedAt: DateTime.utc(2026, 9, 20),
        totalStops: 1,
        completedStops: 0,
        requiredStops: 1,
        completedRequiredStops: 0,
        pointsStatus: RoutePointsStatus.held,
        pointsReason: 'daily_cap',
        heldPoints: 40,
        antifraud: _rules,
        pausedAtLastMarkSeconds: 30,
        stops: [
          _stop(1, 44.0, 34.0, warn: 300).copyWith(
            legDistanceMeters: 1200,
            legEstimateSeconds: 900,
            legEstimateSource: 'provider',
            undelivered: true,
          ),
        ],
      );
      final again = RouteExecution.fromJson(execution.toJson());
      expect(again.pointsStatus, RoutePointsStatus.held);
      expect(again.pointsReason, 'daily_cap');
      expect(again.heldPoints, 40);
      expect(again.antifraud?.gpsToleranceMeters, 150);
      expect(again.pausedAtLastMarkSeconds, 30);
      final stop = again.stops.single;
      expect(stop.legDistanceMeters, 1200);
      expect(stop.legEstimateSeconds, 900);
      expect(stop.legEstimateSource, 'provider');
      expect(stop.paceWarnBelowSeconds, 300);
      expect(stop.undelivered, isTrue);
    });

    test(
      'copyWith keeps unrelated fields and can drop the antifraud block',
      () {
        final execution = RouteExecution(
          id: 'e1',
          routeName: 'Маршрут',
          status: RouteExecutionStatus.active,
          startedAt: DateTime.utc(2026, 9, 20),
          totalStops: 0,
          completedStops: 0,
          requiredStops: 0,
          completedRequiredStops: 0,
          awardedPoints: 12,
          pointsStatus: RoutePointsStatus.awarded,
          antifraud: _rules,
          stops: const [],
        );
        final done = execution.copyWith(status: RouteExecutionStatus.completed);
        expect(done.awardedPoints, 12);
        expect(done.pointsStatus, RoutePointsStatus.awarded);
        expect(done.antifraud, isNotNull);
        expect(execution.copyWith(clearAntifraud: true).antifraud, isNull);
      },
    );

    test('an old server response parses with safe defaults', () {
      final parsed = RouteExecution.fromJson({
        'id': 'e1',
        'status': 'active',
        'stops': [
          {'id': 's1', 'position': 1},
        ],
      });
      expect(parsed.pointsStatus, RoutePointsStatus.none);
      expect(parsed.antifraud, isNull);
      expect(parsed.stops.single.paceWarnBelowSeconds, isNull);
    });
  });
}
