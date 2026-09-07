import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_static_map.dart';

const _config = AppConfig(
  environment: AppEnvironment.local,
  apiBaseUrl: 'http://localhost:8000',
  appName: 'КрымТрип (Test)',
  dataSource: AppDataSource.mock,
);

const _stops = [
  RouteStop(
    id: 'stop-1',
    position: 1,
    placeId: 'place-1',
    placeName: 'Ласточкино гнездо',
    placeSlug: 'lastochkino-gnezdo',
    lat: 44.3927,
    lng: 34.1131,
  ),
  RouteStop(
    id: 'stop-2',
    position: 2,
    placeId: 'place-2',
    placeName: 'Ай-Петри',
    placeSlug: 'ai-petri',
    lat: 44.4517,
    lng: 34.0453,
  ),
];

const _liveMarkerLabel = 'Ваше местоположение';

void main() {
  testWidgets(
    'expanding to full screen keeps the live position marker '
    '(regression: _openFullScreen used to drop livePosition entirely)',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(393, 852);
      addTearDown(() {
        tester.view
          ..resetDevicePixelRatio()
          ..resetPhysicalSize();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RouteStaticMap(
              staticMapUrl: 'https://example.com/static-map.png',
              stops: _stops,
              config: _config,
              livePosition: (lat: 44.42, lng: 34.08),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(_liveMarkerLabel), findsOneWidget);

      await tester.tap(find.byType(RouteStaticMap));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(_liveMarkerLabel),
        findsOneWidget,
        reason:
            'the full-screen map must still show "you are here" — it was '
            'silently dropped before this fix',
      );
    },
  );
}
