import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_execution/application/active_leg.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/active_leg_card.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_static_map.dart';

/// FRONTEND-22: the stretch being walked right now.
void main() {
  final marked = DateTime.utc(2026, 9, 28, 10);

  RouteExecution run({
    required Set<int> done,
    RouteExecutionStatus status = RouteExecutionStatus.active,
  }) => RouteExecution(
    id: 'run',
    routeId: 'route',
    routeName: 'Ялта',
    status: status,
    startedAt: DateTime.utc(2026, 9, 28, 9),
    totalStops: 3,
    completedStops: done.length,
    requiredStops: 3,
    completedRequiredStops: done.length,
    stops: [
      for (final (position, name) in [
        (1, 'Набережная'),
        (2, 'Ливадийский дворец'),
        (3, 'Ласточкино гнездо'),
      ])
        RouteExecutionStop(
          id: 'stop-$position',
          position: position,
          placeName: name,
          isOptional: false,
          completedAt: done.contains(position) ? marked : null,
          legDistanceMeters: 1200,
          legEstimateSeconds: 25 * 60,
        ),
    ],
  );

  group('activeLegInfo', () {
    test('runs from the last marked stop to the next one', () {
      final leg = activeLegInfo(run(done: {1}))!;
      expect(leg.title, 'участок 1–2');
      expect(leg.to.placeName, 'Ливадийский дворец');
      expect(leg.meta, '1,2 км • ≈ 25 мин');
    });

    test('none before the first mark, after the last or while paused', () {
      expect(activeLegInfo(run(done: {})), isNull);
      expect(activeLegInfo(run(done: {1, 2, 3})), isNull);
      expect(
        activeLegInfo(run(done: {1}, status: RouteExecutionStatus.paused)),
        isNull,
      );
    });
  });

  testWidgets('the card names the leg and opens it on the map', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveLegCard(
            leg: activeLegInfo(run(done: {1, 2}))!,
            onShowOnMap: () => opened = true,
          ),
        ),
      ),
    );
    expect(find.text('Сейчас в пути · участок 2–3'), findsOneWidget);
    expect(find.text('Ласточкино гнездо'), findsOneWidget);
    expect(find.text('от «Ливадийский дворец»'), findsOneWidget);
    expect(find.text('1,2 км • ≈ 25 мин'), findsOneWidget);
    await tester.tap(find.byTooltip('Участок на карте'));
    expect(opened, isTrue);
  });

  testWidgets('the map toggle switches between the leg and the route', (
    tester,
  ) async {
    var focus = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Center(
              child: LegFocusToggle(
                focusOnLeg: focus,
                onChanged: (value) => setState(() => focus = value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Участок'));
    await tester.pumpAndSettle();
    expect(focus, isTrue);
    await tester.tap(find.text('Весь маршрут'));
    await tester.pumpAndSettle();
    expect(focus, isFalse);
  });
}
