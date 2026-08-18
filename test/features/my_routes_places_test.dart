import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/my_routes/presentation/my_routes_screen.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/search/presentation/universal_search_panel.dart';

import '../support/test_overrides.dart';

const _place = PlaceSummary(
  id: 'favorite-place',
  name: 'Ласточкино гнездо',
  slug: 'swallow-nest',
  shortDescription: 'Символ Южного берега Крыма',
  lat: 44.4307,
  lng: 34.1235,
  categories: [
    PlaceCategory(
      id: 'heritage',
      code: 'heritage',
      slug: 'heritage',
      name: 'Достопримечательности',
    ),
  ],
);

void main() {
  Future<ProviderContainer> pumpPlaces(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 900);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    final container = ProviderContainer(
      overrides: [
        ...testSessionOverrides(onboardingCompleted: true),
        placesListProvider.overrideWith(
          (ref) async => const PlaceListPage(
            items: [_place],
            total: 1,
            limit: 20,
            offset: 0,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(favoritesProvider.notifier).addPlace(_place.id);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: MyRoutesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('places tab shows favorite places', (tester) async {
    await pumpPlaces(tester);

    expect(find.text('Места'), findsOneWidget);
    await tester.tap(find.text('Места'));
    await tester.pumpAndSettle();

    expect(find.byType(DiscoveryPlaceCard), findsWidgets);
    expect(find.text('Ласточкино гнездо'), findsWidgets);
    expect(find.text('Достопримечательности'), findsWidgets);
  });
}
