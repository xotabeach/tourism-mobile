import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_line_style.dart';

void main() {
  segmentTests();

  test('every stored walking spelling is walked, vehicles are not', () {
    for (final mode in [
      'walk',
      'walking',
      ' Pedestrian ',
      'bicycle',
      null,
      '',
    ]) {
      expect(isWalkingMode(mode), isTrue, reason: '$mode');
    }
    for (final mode in ['car', 'driving', 'mixed', 'public_transport']) {
      expect(isWalkingMode(mode), isFalse, reason: mode);
    }
  });

  test('a dashed line keeps its length in dashes with gaps between', () {
    final line = Path()
      ..moveTo(0, 0)
      ..lineTo(100, 0)
      ..lineTo(100, 70);
    final dashes = dashedPath(line).computeMetrics().toList();
    // 170 px at 10 on, 7 off: ten full periods.
    expect(dashes, hasLength(10));
    final drawn = dashes.fold<double>(0, (sum, m) => sum + m.length);
    expect(drawn, closeTo(100, 0.5));
  });
}

RouteSegment _segment(int leg, int seq, String mode, String role, int meters) =>
    RouteSegment(
      legIndex: leg,
      seq: seq,
      mode: mode,
      role: role,
      distanceMeters: meters,
    );

void segmentTests() {
  test('a drive with a walk up reads as both, in order', () {
    expect(
      legTravelSummary([
        _segment(0, 0, 'car', 'main', 3343),
        _segment(0, 1, 'walk', 'approach', 1392),
      ]),
      'на машине 3,3 км · пешком 1,4 км от парковки',
    );
    expect(
      legTravelSummary([
        _segment(1, 0, 'walk', 'return', 1392),
        _segment(1, 1, 'car', 'main', 4000),
      ]),
      'пешком 1,4 км обратно к машине · на машине 4 км',
    );
  });

  test('a leg walked or driven all the way needs no summary', () {
    expect(legTravelSummary([_segment(0, 0, 'walk', 'main', 900)]), isNull);
    expect(legTravelSummary([_segment(0, 0, 'car', 'main', 9000)]), isNull);
    expect(legTravelSummary(const []), isNull);
  });

  test('route detail parses segments and keeps them for offline', () {
    final json = {
      'id': 'r1',
      'name': 'Бахчисарай',
      'slug': 'bakh',
      'short_description': null,
      'stops_count': 3,
      'description': null,
      'stops': <dynamic>[],
      'segments': [
        {
          'leg_index': 0,
          'seq': 0,
          'mode': 'car',
          'role': 'main',
          'distance_meters': 3343,
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [33.88, 44.74],
              [33.91, 44.74],
            ],
          },
        },
        {
          'leg_index': 0,
          'seq': 1,
          'mode': 'walk',
          'role': 'approach',
          'distance_meters': 1392,
        },
        {
          'leg_index': 1,
          'seq': 0,
          'mode': 'walk',
          'role': 'return',
          'distance_meters': 1392,
        },
      ],
    };
    final route = RouteDetail.fromJson(json);
    expect(route.segments, hasLength(3));
    expect(route.segmentsTo(1).map((s) => s.role), ['main', 'approach']);
    expect(route.segmentsTo(2).single.role, 'return');
    expect(route.segmentsTo(0), isEmpty);
    expect(route.segments.first.geometry!.coordinates, hasLength(2));

    final again = RouteDetail.fromJson(route.toJson());
    expect(again.segments.map((s) => s.mode), ['car', 'walk', 'walk']);
    expect(again.segments.first.geometry!.coordinates.last.lng, 33.91);
  });

  test('older payloads without segments still parse', () {
    final route = RouteDetail.fromJson({
      'id': 'r1',
      'name': 'x',
      'slug': 'x',
      'short_description': null,
      'stops_count': 0,
      'description': null,
      'stops': <dynamic>[],
    });
    expect(route.segments, isEmpty);
  });
}
