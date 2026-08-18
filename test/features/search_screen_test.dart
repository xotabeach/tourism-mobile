import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/search/presentation/universal_search_panel.dart';

import '../support/test_overrides.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1600);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(
          onboardingCompleted: true,
          displayName: 'Никита Можаров',
        ),
        child: const TourismApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('search field on home shows in-place results', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    expect(find.text('Привет, Никита Можаров!'), findsOneWidget);
    expect(find.text('Люди:'), findsOneWidget);
    expect(find.text('Маршруты:'), findsOneWidget);
  });

  testWidgets('in-place search shows results for a query', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'море');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Results area renders discovery cards or the empty-state message.
    final hasCards =
        find.byType(DiscoveryRouteCard).evaluate().isNotEmpty ||
        find.byType(DiscoveryProfileCard).evaluate().isNotEmpty ||
        find.byType(DiscoveryPlaceCard).evaluate().isNotEmpty ||
        find.byType(RouteHeroCard).evaluate().isNotEmpty;
    expect(
      hasCards || find.text('Ничего не найдено').evaluate().isNotEmpty,
      isTrue,
    );
  });
}
