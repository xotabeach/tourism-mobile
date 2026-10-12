import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/execution_map.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

// FRONTEND-70, from «Балаклава и мыс Фиолент»: the road starts 165 m from
// stop 1 and runs 16 m to stop 2, so the highlight on the road alone was
// next to invisible.

const _stop1 = (lat: 44.5, lng: 33.595);
const _stop2 = (lat: 44.501043, lng: 33.5964841);
const _stop3 = (lat: 44.4947842, lng: 33.600155);

RouteExecution _execution() => RouteExecution.fromJson({
  'id': 'run-1',
  'route_id': 'route-1',
  'route_name': 'Балаклава и мыс Фиолент',
  'status': 'active',
  'started_at': '2026-10-12T09:00:00Z',
  'total_stops': 3,
  'completed_stops': 1,
  'required_stops': 3,
  'completed_required_stops': 1,
  'stops': [
    for (final (index, point) in [_stop1, _stop2, _stop3].indexed)
      {
        'id': 's${index + 1}',
        'position': index + 1,
        'place_name': 'Точка ${index + 1}',
        'is_optional': false,
        'lat': point.lat,
        'lng': point.lng,
        'completed_at': index == 0 ? '2026-10-12T09:10:00Z' : null,
      },
  ],
});

Map<String, dynamic> _line(List<List<double>> coordinates) => {
  'type': 'LineString',
  'coordinates': coordinates,
};

RouteDetail _route({bool withSegments = true}) => RouteDetail.fromJson({
  'id': 'route-1',
  'name': 'Балаклава и мыс Фиолент',
  'slug': 'balaklava',
  'stops_count': 3,
  'stops': const <Map<String, dynamic>>[],
  'geometry': _line([
    [33.596648, 44.500908],
    [33.596633, 44.501051],
    [33.5985, 44.4980],
    [33.600155, 44.4949],
  ]),
  if (withSegments)
    'segments': [
      {
        'leg_index': 0,
        'seq': 0,
        'mode': 'car',
        'role': 'main',
        'distance_meters': 16,
        'geometry': _line([
          [33.596648, 44.500908],
          [33.596633, 44.501051],
        ]),
      },
    ],
});

void main() {
  test('the highlighted leg runs from the marked stop to the next one', () {
    final leg = executionActiveLeg(_execution(), _route(withSegments: false))!;
    expect(leg.line.first, _stop1);
    expect(leg.line.last, _stop2);
    expect(leg.line.length, greaterThan(2));
  });

  test('a leg drawn by its segments is anchored to both stops too', () {
    final leg = executionActiveLeg(_execution(), _route())!;
    expect(leg.pieces, hasLength(1));
    expect(leg.pieces.single.line.first, _stop1);
    expect(leg.pieces.single.line.last, _stop2);
    // The road between them is kept.
    expect(leg.pieces.single.line, contains((lat: 44.501051, lng: 33.596633)));
  });
}
