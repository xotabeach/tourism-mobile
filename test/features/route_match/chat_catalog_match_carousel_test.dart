import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/widgets/chat_catalog_match_carousel.dart';

import '../../support/test_overrides.dart';

void main() {
  testWidgets('ChatCatalogMatchCarousel opens route on arrow tap', (
    tester,
  ) async {
    String? openedId;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(testAppConfig)],
        child: MaterialApp(
          home: Scaffold(
            body: ChatCatalogMatchCarousel(
              routes: const [
                CatalogRouteItem(
                  routeId: 'route-1',
                  title: 'Ялта · море',
                  coverUrl: 'https://example.com/cover.jpg',
                  rating: 4.7,
                  distanceKm: 10.2,
                  localityLabel: 'Ялта',
                  tags: ['Пляж'],
                ),
                CatalogRouteItem(routeId: 'route-2', title: 'Алушта · горы'),
              ],
              onOpenRoute: (id) => openedId = id,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ялта · море'), findsOneWidget);
    // Tags render below the photo (design-spec screen 2), not overlaid on it.
    expect(find.text('Пляж'), findsOneWidget);
    // Distance shows both in the compact photo overlay and the param row.
    expect(find.textContaining('10,2 км'), findsWidgets);
    // Pages are full width now (FRONTEND-12: the card follows the bubble's
    // grid), but the PageView may still build the next one — target the
    // first arrow explicitly.
    await tester.tap(find.byIcon(Icons.arrow_forward).first);
    await tester.pump();
    expect(openedId, 'route-1');
  });

  testWidgets(
    'a card shows the percent snapshot with the main mismatch, old ones do not',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appConfigProvider.overrideWithValue(testAppConfig)],
          child: MaterialApp(
            home: Scaffold(
              body: ChatCatalogMatchCarousel(
                routes: const [
                  CatalogRouteItem(
                    routeId: 'route-1',
                    title: 'Ялта · море',
                    tags: ['Пляж'],
                    matchPercent: 75,
                    mainMismatch: 'старт не совпал',
                  ),
                  CatalogRouteItem(
                    routeId: 'route-2',
                    title: 'Алушта · горы',
                    tags: ['Горы'],
                  ),
                ],
                onOpenRoute: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Подходит на 75% · старт не совпал'), findsOneWidget);
      expect(find.textContaining('Подходит на'), findsOneWidget);
    },
  );
}
