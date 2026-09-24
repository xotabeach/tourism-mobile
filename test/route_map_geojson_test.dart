import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_interactive_map.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_geojson.dart';

RouteGeometry _line(List<(double, double)> points) => RouteGeometry(
  coordinates: [
    for (final (lng, lat) in points) RouteCoordinate(lng: lng, lat: lat),
  ],
);

RouteSegment _segment(String mode, String role) => RouteSegment(
  legIndex: 0,
  seq: 0,
  mode: mode,
  role: role,
  geometry: _line([(33.88, 44.74), (33.92, 44.74)]),
);

void main() {
  test('segments are drawn each in its way, the walk back left out', () {
    final json = routeLinesGeoJson(
      geometry: null,
      segments: [
        _segment('car', 'main'),
        _segment('walk', 'approach'),
        _segment('walk', 'return'),
      ],
      dashed: false,
    );
    final props = [
      for (final f in json['features'] as List) (f as Map)['properties'],
    ];
    expect(props, [
      {'mode': 'car', 'dashed': false},
      {'mode': 'walk', 'dashed': true},
    ]);
  });

  test('a route without segments is one line in its own way', () {
    final walked = routeLinesGeoJson(
      geometry: _line([(34.1, 44.4), (34.2, 44.5)]),
      segments: const [],
      dashed: true,
    );
    final feature = (walked['features'] as List).single as Map;
    expect(feature['properties'], {'mode': 'walk', 'dashed': true});
    expect((feature['geometry'] as Map)['coordinates'], [
      [34.1, 44.4],
      [34.2, 44.5],
    ]);
    expect(
      (routeLinesGeoJson(
                geometry: null,
                segments: const [],
                dashed: false,
              )['features']
              as List)
          .isEmpty,
      isTrue,
    );
  });

  test('stops are numbered in order and marked done', () {
    const stops = [
      RouteStop(
        id: 'a',
        position: 1,
        placeId: 'a',
        placeName: 'A',
        placeSlug: 'a',
        lat: 44.4,
        lng: 34.1,
      ),
      RouteStop(
        id: 'b',
        position: 2,
        placeId: 'b',
        placeName: 'B',
        placeSlug: 'b',
      ),
      RouteStop(
        id: 'c',
        position: 3,
        placeId: 'c',
        placeName: 'C',
        placeSlug: 'c',
        lat: 44.5,
        lng: 34.2,
      ),
    ];
    final json = stopsGeoJson(stops, completedPositions: {1});
    final props = [
      for (final f in json['features'] as List) (f as Map)['properties'],
    ];
    // B has no coordinates: not drawn, but numbering follows the route.
    expect(props.map((p) => (p as Map)['label']), ['1', '3']);
    expect(props.map((p) => (p as Map)['done']), [true, false]);
  });

  test('the frame spans every point and is empty without any', () {
    final bounds = boundsOf([
      (lat: 44.4, lng: 34.2),
      (lat: 44.6, lng: 34.0),
      (lat: 44.5, lng: 34.1),
    ])!;
    expect(bounds.southWest, (lat: 44.4, lng: 34.0));
    expect(bounds.northEast, (lat: 44.6, lng: 34.2));
    expect(boundsOf(const []), isNull);
  });

  test('the style comes from the map path of the API host', () {
    const config = AppConfig(
      environment: AppEnvironment.production,
      apiBaseUrl: 'https://201-24-55-130.sslip.io',
      appName: 'КрымТрип',
      dataSource: AppDataSource.api,
    );
    expect(
      RouteInteractiveMap.styleUrl(config),
      'https://201-24-55-130.sslip.io/map/styles/crimeatrip/style.json',
    );
  });
}
