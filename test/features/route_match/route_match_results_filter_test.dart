import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_match/application/route_match_providers.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_results_screen.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

import '../../support/test_overrides.dart';

const _seaRoute = RouteSummary(
  id: 'match-sea',
  name: 'Прогулка у моря',
  slug: 'match-sea',
  shortDescription: 'Маршрут вдоль берега',
  stopsCount: 3,
);

const _mountainRoute = RouteSummary(
  id: 'match-mountain',
  name: 'Восхождение в горы',
  slug: 'match-mountain',
  shortDescription: 'Горный маршрут со скалами',
  stopsCount: 4,
);

const _matchResult = RouteMatchResult(
  strategy: 'form',
  ideal: [
    RouteMatchHit(route: _seaRoute, score: 0.9, band: 'ideal', reasons: []),
    RouteMatchHit(
      route: _mountainRoute,
      score: 0.85,
      band: 'ideal',
      reasons: [],
    ),
  ],
  close: [],
  offerGenerate: false,
  aiRerankEligible: false,
  aiRerankApplied: false,
  scoredTotal: 2,
);

void main() {
  testWidgets('filter tap narrows route match results by category', (
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

    final container = ProviderContainer(
      overrides: [
        ...testSessionOverrides(onboardingCompleted: true),
        lastRouteMatchResultProvider.overrideWith((ref) => _matchResult),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RouteMatchResultsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_seaRoute.name), findsOneWidget);
    expect(find.text(_mountainRoute.name), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Фильтры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Горы'));
    await tester.pumpAndSettle();

    expect(find.text(_mountainRoute.name), findsOneWidget);
    expect(find.text(_seaRoute.name), findsNothing);

    await tester.tap(find.bySemanticsLabel('Фильтры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Все'));
    await tester.pumpAndSettle();

    expect(find.text(_seaRoute.name), findsOneWidget);
    expect(find.text(_mountainRoute.name), findsOneWidget);
  });
}
