import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/widgets/chat_catalog_match_carousel.dart';

void main() {
  testWidgets('ChatCatalogMatchCarousel opens route on arrow tap', (
    tester,
  ) async {
    String? openedId;
    await tester.pumpWidget(
      MaterialApp(
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
    );

    expect(find.text('Ялта · море'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();
    expect(openedId, 'route-1');
  });
}
