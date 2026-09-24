import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/route_publish/application/route_publish_controller.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_publish_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/map_projection.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_static_map.dart';

const _config = AppConfig(
  environment: AppEnvironment.local,
  apiBaseUrl: 'http://localhost:8000',
  appName: 'test',
  dataSource: AppDataSource.mock,
);

RouteLocation _place(String id, double lat, double lng) =>
    RouteLocation(id: id, name: id, subtitle: '', lat: lat, lng: lng);

Future<void> _pumpCard(
  WidgetTester tester,
  RouteDraft draft, {
  String? error,
  VoidCallback? onRetry,
}) async {
  debugRouteMapImage = (_) => MemoryImage(_png);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RouteMapPreviewCard(
          u: (value) => value,
          golden: false,
          draft: draft,
          onTap: () {},
          config: _config,
          previewError: error,
          onRetryPreview: onRetry,
        ),
      ),
    ),
  );
}

// 1×1 transparent PNG.
final _png = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x60,
  0x00,
  0x02,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0xE9,
  0xFA,
  0xDC,
  0xD8,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  tearDown(() => debugRouteMapImage = null);

  test('one point is framed like a place, not at the closest zoom', () {
    final projection = MapProjection.fit(
      points: [(lat: 44.451, lng: 34.055)],
      size: const Size(377, 320),
    )!;
    expect(projection.zoom, MapProjection.singlePointZoom);
    expect((projection.centerLat, projection.centerLng), (44.451, 34.055));
  });

  test('the points map asks the server for published places by id', () {
    expect(pointsMapPath(['a', 'b']), '/api/v1/maps/static/points/p1/a,b');
  });

  test('a failed line says why', () {
    expect(
      routePreviewErrorText(
        const RejectedFailure('bad', 'invalid_route_place'),
      ),
      'Одна из точек недоступна для маршрута. Замените её.',
    );
    expect(
      routePreviewErrorText(const NetworkFailure()),
      'Нет связи, линия маршрута не построена.',
    );
    expect(
      routePreviewErrorText(StateError('x')),
      'Не удалось построить линию маршрута.',
    );
  });

  testWidgets('one point already shows the real map', (tester) async {
    await _pumpCard(
      tester,
      RouteDraft(start: _place('ai-petri', 44.451, 34.055)),
    );
    expect(find.byKey(const ValueKey('route-map-preview-points')), findsOne);
    expect(find.byType(RouteStaticMap), findsOne);
  });

  testWidgets('a failed line is shown with a retry', (tester) async {
    var retried = 0;
    await _pumpCard(
      tester,
      RouteDraft(
        start: _place('ai-yori', 44.673, 34.339),
        finish: _place('ai-petri', 44.451, 34.055),
      ),
      error: 'Не удалось построить линию маршрута.',
      onRetry: () => retried++,
    );
    expect(find.text('Не удалось построить линию маршрута.'), findsOne);
    await tester.tap(find.text('Повторить'));
    expect(retried, 1);
  });
}
