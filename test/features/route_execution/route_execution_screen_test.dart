import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_providers.dart';
import 'package:tourism_mobile/features/route_execution/data/mock_route_execution_repository.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/route_execution_screen.dart';
import 'package:tourism_mobile/routing/app_router.dart';

import '../../support/test_overrides.dart';

class _Repo extends MockRouteExecutionRepository {
  final unmarked = <String>[];
  var starts = 0;
  RouteExecution? _run;

  @override
  Future<RouteExecution> uncompleteStop(
    String executionId,
    String stopId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async {
    unmarked.add(stopId);
    final run = _run!;
    final stops = [
      for (final stop in run.stops)
        stop.id == stopId ? stop.withoutCompletion() : stop,
    ];
    return _run = run.copyWith(
      stops: stops,
      completedStops: stops.where((stop) => stop.isCompleted).length,
    );
  }

  @override
  Future<RouteExecution> start(String routeId) async {
    starts += 1;
    final now = DateTime.now();
    return _run = RouteExecution(
      id: 'run-1',
      routeId: routeId,
      routeName: 'Алушта: от гор к набережной',
      status: RouteExecutionStatus.active,
      startedAt: now.subtract(const Duration(minutes: 174)),
      totalStops: 4,
      completedStops: 1,
      requiredStops: 4,
      completedRequiredStops: 1,
      stops: [
        for (var i = 0; i < 4; i++)
          RouteExecutionStop(
            id: 's$i',
            position: i + 1,
            placeName: 'Точка ${i + 1}',
            isOptional: false,
            legDistanceMeters: i == 0 ? null : 3500,
            completedAt: i == 0 ? now : null,
          ),
      ],
    );
  }
}

Future<void> _openRunScreen(
  WidgetTester tester,
  _Repo repo, {
  bool openOnly = false,
}) async {
  for (final channel in [
    'flutter.baseflow.com/geolocator',
    'flutter.baseflow.com/geolocator_updates',
  ]) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      MethodChannel(channel),
      (call) async => switch (call.method) {
        'checkPermission' || 'requestPermission' => 2,
        'isLocationServiceEnabled' => true,
        _ => null,
      },
    );
  }
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 1400);
  addTearDown(tester.view.reset);
  await pumpTourismAppAtHome(
    tester,
    overrides: [routeExecutionRepositoryProvider.overrideWithValue(repo)],
  );
  unawaited(
    GoRouter.of(tester.element(find.byType(HomeScreen))).pushNamed(
      AppRouteNames.routeExecution,
      pathParameters: {'id': 'route-south-coast'},
      queryParameters: openOnly ? const {'open': '1'} : const {},
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('the run screen follows the design layout', (tester) async {
    await _openRunScreen(tester, _Repo());
    expect(find.byType(RouteExecutionScreen), findsOneWidget);
    expect(find.text('Прохождение'), findsOneWidget);
    expect(find.text('Прогресс:'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(find.bySemanticsLabel('Всего в пути: 174 мин.'), findsOneWidget);
    expect(find.text('Остановки:'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Пауза'), findsOneWidget);
    expect(
      find.bySemanticsLabel('«Точка 1» отмечена, снять отметку'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Отметить «Точка 2»'), findsOneWidget);
    expect(find.text('3,5 км'), findsWidgets);
    // Without a location fix the row says it is the whole leg, not a distance
    // from the phone.
    expect(find.text('весь участок 3,5 км'), findsOneWidget);
    expect(find.bySemanticsLabel('Завершить маршрут'), findsOneWidget);
    // The separate «Пауза» button and the old «Готово» buttons are gone.
    expect(find.text('Готово'), findsNothing);

    // Leave the screen so its minute clock is disposed.
    GoRouter.of(tester.element(find.byType(RouteExecutionScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the latest mark can be taken back after a confirmation', (
    tester,
  ) async {
    final repo = _Repo();
    await _openRunScreen(tester, repo);

    await tester.tap(
      find.bySemanticsLabel('«Точка 1» отмечена, снять отметку'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Снять отметку?'), findsOneWidget);
    await tester.tap(find.text('Снять отметку'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(repo.unmarked, ['s0']);
    expect(find.text('0/4'), findsOneWidget);
    expect(find.bySemanticsLabel('Отметить «Точка 1»'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(RouteExecutionScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('opened from the home card, a finished run is not restarted', (
    tester,
  ) async {
    // FRONTEND-34: the card can outlive its run (finished on another
    // device); tapping it must not start the route again.
    final repo = _Repo();
    await _openRunScreen(tester, repo, openOnly: true);

    expect(repo.starts, 0);
    expect(find.text('Прохождение уже завершено'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(RouteExecutionScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
  });
}
