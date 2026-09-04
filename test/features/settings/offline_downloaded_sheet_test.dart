import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/routes/application/offline_routes_provider.dart';
import 'package:tourism_mobile/features/routes/data/offline_route_store.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_prefs_screens.dart';

import '../../support/test_overrides.dart';

/// Шторка скачанных маршрутов рисовалась «как получилось» — на макете
/// («Настройки Оффлайн», 2026-09-04) это голубые плашки с синей галочкой,
/// названием, строкой «2 остановки • скачан …» и крестиком справа.
RouteDetail _route(String id, String name) => RouteDetail(
  id: id,
  name: name,
  slug: id,
  shortDescription: 'От гор к набережной',
  stopsCount: 2,
  description: null,
  stops: const [
    RouteStop(
      id: 's1',
      position: 1,
      placeId: 'p1',
      placeName: 'Гора',
      placeSlug: 'gora',
    ),
    RouteStop(
      id: 's2',
      position: 2,
      placeId: 'p2',
      placeName: 'Набережная',
      placeSlug: 'naberezhnaya',
    ),
  ],
);

void main() {
  testWidgets('the downloaded-routes sheet lists routes the way the mockup does', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 900);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          offlineRoutesProvider.overrideWith(
            (ref) async => [
              OfflineRouteRecord(
                route: _route('r1', 'Алушта: от гор к набережной'),
                downloadedAt: DateTime(2026, 9),
              ),
              OfflineRouteRecord(
                route: _route('r2', 'Ялта: набережная и канатка'),
                downloadedAt: DateTime(2026, 9, 2),
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SettingsOfflineScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Скачанные маршруты'));
    await tester.pumpAndSettle();

    // Заголовок шторки и счётчик.
    expect(find.text('Скачанные маршруты'), findsWidgets);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Алушта: от гор к набережной'), findsOneWidget);
    expect(
      find.textContaining('2 остановки • скачан 01.09.2026'),
      findsOneWidget,
    );
    // Синяя галочка у каждой строки и крестик вместо корзины.
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsNWidgets(2));
    // Крестик у каждой строки — на макете именно он, а не корзина.
    expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));
  });
}
