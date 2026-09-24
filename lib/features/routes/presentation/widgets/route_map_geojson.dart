import 'package:tourism_mobile/features/routes/domain/route.dart';

/// GeoJSON for the interactive route map (spec 12a-9). Pure, so it is
/// tested without a platform map view.

typedef MapPoint = ({double lat, double lng});

/// Colours match the server image (spec 14, D23): walking green and dashed,
/// driving blue, other transport amber, all solid but walking.
const mapWalkColor = '#16A34A';
const mapCarColor = '#2563EB';
const mapTransitColor = '#F59E0B';
const mapActiveLegColor = '#3B82F6';

Map<String, dynamic> _feature(
  Map<String, dynamic> geometry,
  Map<String, dynamic> properties,
) => {'type': 'Feature', 'geometry': geometry, 'properties': properties};

Map<String, dynamic> featureCollection(List<Map<String, dynamic>> features) => {
  'type': 'FeatureCollection',
  'features': features,
};

List<List<double>> _coordinates(Iterable<MapPoint> points) => [
  for (final point in points) [point.lng, point.lat],
];

/// The route line: one feature per segment when the route has them (the
/// walk back to the car left out, it retraces the approach), else the whole
/// line in the route's own way.
Map<String, dynamic> routeLinesGeoJson({
  required RouteGeometry? geometry,
  required List<RouteSegment> segments,
  required bool dashed,
}) {
  final drawn = [
    for (final segment in segments)
      if (segment.role != 'return' &&
          (segment.geometry?.coordinates.length ?? 0) >= 2)
        segment,
  ];
  if (drawn.isNotEmpty) {
    return featureCollection([
      for (final segment in drawn)
        _feature(
          {
            'type': 'LineString',
            'coordinates': _coordinates(
              segment.geometry!.coordinates.map(
                (c) => (lat: c.lat, lng: c.lng),
              ),
            ),
          },
          {'mode': segment.mode, 'dashed': segment.isWalk},
        ),
    ]);
  }
  final line = geometry?.coordinates ?? const <RouteCoordinate>[];
  if (line.length < 2) return featureCollection(const []);
  return featureCollection([
    _feature(
      {
        'type': 'LineString',
        'coordinates': _coordinates(line.map((c) => (lat: c.lat, lng: c.lng))),
      },
      {'mode': dashed ? 'walk' : 'car', 'dashed': dashed},
    ),
  ]);
}

/// Numbered stops; a marked one is drawn done.
Map<String, dynamic> stopsGeoJson(
  List<RouteStop> stops, {
  Set<int> completedPositions = const {},
  int? selectedIndex,
}) => featureCollection([
  for (var index = 0; index < stops.length; index++)
    if (stops[index].lat != null && stops[index].lng != null)
      _feature(
        {
          'type': 'Point',
          'coordinates': [stops[index].lng, stops[index].lat],
        },
        {
          'label': '${index + 1}',
          'done': completedPositions.contains(stops[index].position),
          'selected': selectedIndex == index,
        },
      ),
]);

Map<String, dynamic> lineGeoJson(List<MapPoint> line) => featureCollection([
  if (line.length >= 2)
    _feature({
      'type': 'LineString',
      'coordinates': _coordinates(line),
    }, const {}),
]);

Map<String, dynamic> pointGeoJson(MapPoint? point) => featureCollection([
  if (point != null)
    _feature({
      'type': 'Point',
      'coordinates': [point.lng, point.lat],
    }, const {}),
]);

/// South-west and north-east corners around [points]; null when empty.
({MapPoint southWest, MapPoint northEast})? boundsOf(
  Iterable<MapPoint> points,
) {
  double? south, west, north, east;
  for (final point in points) {
    south = south == null || point.lat < south ? point.lat : south;
    north = north == null || point.lat > north ? point.lat : north;
    west = west == null || point.lng < west ? point.lng : west;
    east = east == null || point.lng > east ? point.lng : east;
  }
  if (south == null || west == null || north == null || east == null) {
    return null;
  }
  return (
    southWest: (lat: south, lng: west),
    northEast: (lat: north, lng: east),
  );
}
