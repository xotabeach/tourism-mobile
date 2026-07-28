import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/routes/application/favorite_routes_provider.dart';
import 'package:tourism_mobile/features/routes/application/route_catalog_filter.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_swipe_deck.dart';

const _seaRoute = RouteSummary(
  id: 'sea',
  name: 'Море и сосны',
  slug: 'sea',
  shortDescription: 'Береговая тропа у бухты',
  stopsCount: 2,
);

const _mountainRoute = RouteSummary(
  id: 'mountain',
  name: 'Подъем на Ай-Петри',
  slug: 'mountain',
  shortDescription: 'Горный маршрут',
  stopsCount: 3,
);

void main() {
  test('favorite controller stores immutable route ids', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(favoriteRouteIdsProvider.notifier).add(_seaRoute.id);

    expect(container.read(favoriteRouteIdsProvider), {_seaRoute.id});
    container.read(favoriteRouteIdsProvider.notifier).remove(_seaRoute.id);
    expect(container.read(favoriteRouteIdsProvider), isEmpty);
  });

  test('route catalog filter changes the visible route set', () {
    const routes = [_seaRoute, _mountainRoute];

    expect(filterRouteCatalog(routes, 'Все'), same(routes));
    expect(filterRouteCatalog(routes, 'Море'), [_seaRoute]);
    expect(filterRouteCatalog(routes, 'Горы'), [_mountainRoute]);
    expect(filterRouteCatalog(routes, 'Еда'), isEmpty);
  });

  testWidgets('committed right swipe updates observed favorite state', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: RouteSwipeDeck(
              routes: const [_seaRoute, _mountainRoute],
              onSwipe: (route, action) {
                if (action == RouteSwipeAction.favorite) {
                  container
                      .read(favoriteRouteIdsProvider.notifier)
                      .add(route.id);
                }
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('route-swipe-card-translation')),
      const Offset(180, 0),
    );
    await tester.pumpAndSettle();

    expect(container.read(favoriteRouteIdsProvider), {_seaRoute.id});
  });

  testWidgets('dismissing coach promotes first card without jump', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });
    var showCoach = true;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: RouteSwipeDeck(
                  routes: const [_seaRoute, _mountainRoute],
                  onSwipe: (_, _) {},
                  showCoach: showCoach,
                  onCoachDismiss: () => setState(() => showCoach = false),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RouteSwipeCoachCard), findsOneWidget);
    tester
        .widget<RouteSwipeCoachCard>(find.byType(RouteSwipeCoachCard))
        .onDismiss();
    await tester.pump();

    final promotedRoute = find.byKey(const ValueKey('route-layer-sea'));
    final settleStartTop = tester.widget<Positioned>(promotedRoute).top!;
    expect(settleStartTop, closeTo(-6, 0.2));

    await tester.pump(const Duration(milliseconds: 170));
    final settleMidTop = tester.widget<Positioned>(promotedRoute).top!;
    expect(settleMidTop, greaterThan(settleStartTop));
    expect(settleMidTop, lessThan(17));

    await tester.pumpAndSettle();
    expect(tester.widget<Positioned>(promotedRoute).top, closeTo(17, 0.01));
  });
}
