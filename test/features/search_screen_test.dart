import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/search/application/search_history_provider.dart';
import 'package:tourism_mobile/features/search/presentation/in_place_search.dart';
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
    final viewport = tester.getRect(
      find.byKey(const ValueKey('search-horizontal-viewport')).first,
    );
    expect(viewport.left, closeTo(0, 0.5));
    expect(viewport.right, closeTo(393, 0.5));
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

  testWidgets('tapping the saved query fills the search through callback', (
    tester,
  ) async {
    final store = MemorySearchHistoryStore();
    await store.save('mock-user', ['Крымский завтрак']);
    String? applied;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          searchHistoryProvider.overrideWith(
            (ref) =>
                SearchHistoryController(store: store, ownerKey: 'mock-user'),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: InPlaceSearchBody(
              query: '',
              localRoutes: const [],
              onQueryFromHistory: (value) => applied = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Крымский завтрак'));
    await tester.pump();
    expect(applied, 'Крымский завтрак');
  });

  testWidgets('tapping an active search target clears it', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.bySemanticsLabel('Фильтры'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.text('Пользователи'));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));

    await tester.tap(find.text('Пользователи'));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('dragging the filter sheet handle down dismisses the sheet', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.bySemanticsLabel('Фильтры'));
    await tester.pumpAndSettle();
    expect(find.text('Что ищем?'), findsOneWidget);

    final sheet = find.byType(BottomSheet);
    final start =
        tester.getTopLeft(sheet) + Offset(tester.getSize(sheet).width / 2, 8);
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump(const Duration(milliseconds: 80));
    await gesture.moveBy(const Offset(0, 900));
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Что ищем?'), findsNothing);
  });
}
