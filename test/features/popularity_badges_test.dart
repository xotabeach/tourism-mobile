import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/places/data/place_view_reporter.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

// Spec 19: the server marks popular places and routes and editorial routes
// with a badge, and learns about opened place cards from the app.

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int statusCode = 204;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromBytes(utf8.encode(''), statusCode);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _routeJson({String? badge}) => {
  'id': 'r1',
  'name': 'Тропа',
  'slug': 'tropa',
  'short_description': null,
  'stops_count': 3,
  'transport_mode': 'walk',
  'difficulty': 'moderate',
  'badge': ?badge,
};

Map<String, dynamic> _placeJson({String? badge}) => {
  'id': 'p1',
  'name': 'Ласточкино гнездо',
  'slug': 'lastochkino-gnezdo',
  'short_description': null,
  'lat': 44.43,
  'lng': 34.13,
  'categories': <dynamic>[],
  'badge': ?badge,
};

void main() {
  group('badge on a route', () {
    test('is the first chip of the card', () {
      final popular = RouteSummary.fromJson(_routeJson(badge: 'popular'));
      final editorial = RouteSummary.fromJson(
        _routeJson(badge: 'editors_choice'),
      );

      expect(routeTagLabels(popular).first, 'Популярное');
      expect(routeTagLabels(editorial).first, 'Выбор редакции');
    });

    test('is absent for no badge and for a value this build does not know', () {
      final plain = RouteSummary.fromJson(_routeJson());
      final unknown = RouteSummary.fromJson(_routeJson(badge: 'trending'));

      expect(routeTagLabels(plain), routeTagLabels(unknown));
      expect(routeTagLabels(plain), isNot(contains('Популярное')));
      expect(routeBadgeLabel('trending'), isNull);
    });

    test('survives the offline cache round trip', () {
      final route = RouteSummary.fromJson(_routeJson(badge: 'popular'));

      expect(RouteSummary.fromJson(route.toJson()).badge, 'popular');
    });
  });

  test('a place carries its badge into the detail model', () {
    final detail = PlaceDetail.fromJson(_placeJson(badge: 'popular'));

    expect(detail.badge, 'popular');
    expect(PlaceSummary.fromJson(_placeJson()).badge, isNull);
  });

  group('place view reporter', () {
    late _Adapter adapter;
    late Dio dio;
    var now = DateTime.utc(2026, 10, 8, 10);

    setUp(() {
      adapter = _Adapter();
      dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      now = DateTime.utc(2026, 10, 8, 10);
    });

    test('sends one view per place and day', () async {
      final reporter = PlaceViewReporter(
        dio,
        isEnabled: () => true,
        now: () => now,
      );

      reporter
        ..report('p1')
        ..report('p1')
        ..report('p2');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(adapter.requests.map((request) => request.path), [
        '/api/v1/places/p1/view',
        '/api/v1/places/p2/view',
      ]);
      expect(adapter.requests.first.method, 'POST');

      now = DateTime.utc(2026, 10, 9, 10);
      reporter.report('p1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(adapter.requests, hasLength(3));
    });

    test('stays silent for a guest', () async {
      PlaceViewReporter(
        dio,
        isEnabled: () => false,
        now: () => now,
      ).report('p1');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(adapter.requests, isEmpty);
    });

    test('tries again after a failed request', () async {
      final reporter = PlaceViewReporter(
        dio,
        isEnabled: () => true,
        now: () => now,
      );
      adapter.statusCode = 500;
      reporter.report('p1');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      adapter.statusCode = 204;
      reporter.report('p1');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(adapter.requests, hasLength(2));
    });
  });
}
