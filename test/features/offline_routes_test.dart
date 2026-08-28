import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourism_mobile/features/routes/data/offline_route_store.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

RouteDetail _route(String id) => RouteDetail(
  id: id,
  name: 'Тестовый маршрут $id',
  slug: 'test-$id',
  shortDescription: 'Описание',
  stopsCount: 1,
  description: 'Подробное описание',
  geometry: const RouteGeometry(
    coordinates: [
      RouteCoordinate(lng: 34.1, lat: 44.5),
      RouteCoordinate(lng: 34.2, lat: 44.6),
    ],
  ),
  routing: const RouteRoutingInfo(
    provider: '2gis',
    qualityStatus: 'needs_review',
    qualityPolicyVersion: 'v1',
    warnings: ['slope_above_requested_pace'],
    movementDurationSeconds: 900,
    visitDurationMinutes: 45,
    totalDurationSeconds: 3600,
    elevationGainMeters: 120,
    minAltitudeMeters: -3,
    maxAltitudeMeters: 430,
  ),
  stops: [
    RouteStop(
      id: 'stop-$id',
      position: 1,
      placeId: 'place-$id',
      placeName: 'Точка',
      placeSlug: 'point-$id',
      lat: 44.5,
      lng: 34.1,
    ),
  ],
);

void main() {
  test(
    'shared preferences store round-trips a complete route snapshot',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesOfflineRouteStore();

      await store.save(_route('one'));

      final record = await store.get('one');
      expect(record, isNotNull);
      expect(record!.route.name, 'Тестовый маршрут one');
      expect(record.route.stops.single.placeId, 'place-one');
      expect(record.route.geometry!.coordinates.length, 2);
      expect(record.route.routing!.qualityStatus, 'needs_review');
      expect(record.route.routing!.qualityPolicyVersion, 'v1');
      expect(record.route.routing!.totalDurationSeconds, 3600);
      expect(record.route.routing!.minAltitudeMeters, -3);
      expect((await store.list()).map((item) => item.id), contains('one'));

      await store.remove('one');
      expect(await store.get('one'), isNull);
    },
  );

  test('clear removes only the versioned offline route namespace', () async {
    SharedPreferences.setMockInitialValues({'unrelated': 'keep'});
    final store = SharedPreferencesOfflineRouteStore();
    await store.save(_route('one'));
    await store.save(_route('two'));

    await store.clear();

    expect(await store.list(), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('unrelated'), 'keep');
  });
}
