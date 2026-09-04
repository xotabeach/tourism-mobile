import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/my_routes/presentation/my_routes_screen.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

import '../support/test_overrides.dart';

const _route = RouteSummary(
  id: 'favorite-route',
  name: 'Тропа к морю',
  slug: 'coast-favorite',
  shortDescription: 'Маршрут вдоль берега',
  stopsCount: 3,
  distanceMeters: 4200,
  difficulty: 'easy',
  transportMode: 'walk',
);

const _mountainRoute = RouteSummary(
  id: 'favorite-route-mountain',
  name: 'Тропа на Ай-Петри',
  slug: 'mountain-favorite',
  shortDescription: 'Горный маршрут со скалами',
  stopsCount: 4,
  distanceMeters: 5100,
  difficulty: 'hard',
  transportMode: 'walk',
);

void main() {
  Future<ProviderContainer> pumpFavorites(
    WidgetTester tester, {
    List<RouteSummary> extraRoutes = const [],
  }) async {
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
        routesListProvider.overrideWith(
          (ref) async => RouteListPage(
            items: [_route, ...extraRoutes],
            total: 1 + extraRoutes.length,
            limit: 20,
            offset: 0,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(favoritesProvider.notifier).addRoute(_route.id);
    for (final route in extraRoutes) {
      await container.read(favoritesProvider.notifier).addRoute(route.id);
    }

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

  testWidgets('left swipe removes favorite and undo restores it', (
    tester,
  ) async {
    final container = await pumpFavorites(tester);
    final dismissible = find.byKey(
      const ValueKey('favorite-dismiss-favorite-route'),
    );

    expect(dismissible, findsOneWidget);
    await tester.drag(dismissible, const Offset(-70, 0));
    await tester.pump();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('favorite-remove-background')))
          .height,
      tester.getSize(find.byType(RouteHeroCard)).height,
    );
    await tester.pumpAndSettle();
    expect(container.read(favoritesProvider).routeIds, {_route.id});
    expect(find.text('Убрать'), findsOneWidget);

    await tester.drag(dismissible, const Offset(-240, 0));
    await tester.pumpAndSettle();

    expect(container.read(favoritesProvider).routeIds, isEmpty);
    expect(find.textContaining('удалён из избранного'), findsOneWidget);

    await tester.tap(find.text('Вернуть'));
    await tester.pumpAndSettle();

    expect(container.read(favoritesProvider).routeIds, {_route.id});
    expect(dismissible, findsOneWidget);
  });

  testWidgets('heart action stages exit before removing favorite', (
    tester,
  ) async {
    final container = await pumpFavorites(tester);

    await tester.tap(
      find.byKey(const ValueKey('favorite-toggle-favorite-route')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    expect(container.read(favoritesProvider).routeIds, {_route.id});

    await tester.pump(const Duration(milliseconds: 360));
    await tester.pump();

    expect(container.read(favoritesProvider).routeIds, isEmpty);
    expect(find.textContaining('удалён из избранного'), findsOneWidget);
  });

  testWidgets('the filters sheet narrows favorites by tag', (tester) async {
    await pumpFavorites(tester, extraRoutes: [_mountainRoute]);

    expect(find.text(_route.name), findsOneWidget);
    expect(find.text(_mountainRoute.name), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Фильтры'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Горы'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Горы'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();

    expect(find.text(_mountainRoute.name), findsOneWidget);
    expect(find.text(_route.name), findsNothing);

    await tester.tap(find.bySemanticsLabel('Фильтры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();

    expect(find.text(_route.name), findsOneWidget);
    expect(find.text(_mountainRoute.name), findsOneWidget);
  });

  testWidgets('the sheet only offers what the open section can be sorted by', (
    tester,
  ) async {
    await pumpFavorites(tester);

    // Маршруты: рейтинг есть, даты у карточки нет — «сначала новые» врало бы.
    await tester.tap(find.bySemanticsLabel('Фильтры'));
    await tester.pumpAndSettle();
    expect(find.text('Что ищем?'), findsNothing);
    expect(find.text('С высоким рейтингом'), findsOneWidget);
    expect(find.text('Сначала новые'), findsNothing);
    expect(find.text('Горы'), findsOneWidget);
    await tester.ensureVisible(find.text('Применить'));
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();

    // Подписки: у людей нет ни рейтинга, ни тегов.
    await selectMyRoutesSection(tester, 'Подписки');

    await tester.tap(find.bySemanticsLabel('Фильтры'));
    await tester.pumpAndSettle();
    expect(find.text('С высоким рейтингом'), findsNothing);
    expect(find.text('По алфавиту'), findsOneWidget);
    expect(find.text('Фильтры'), findsNothing);
    expect(find.text('Горы'), findsNothing);
  });
}
