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
  @override
  Future<RouteExecution> start(String routeId) async {
    final now = DateTime.now();
    return RouteExecution(
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

void main() {
  testWidgets('the run screen follows the design layout', (tester) async {
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
      overrides: [routeExecutionRepositoryProvider.overrideWithValue(_Repo())],
    );
    unawaited(
      GoRouter.of(tester.element(find.byType(HomeScreen))).pushNamed(
        AppRouteNames.routeExecution,
        pathParameters: {'id': 'route-south-coast'},
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.byType(RouteExecutionScreen), findsOneWidget);
    expect(find.text('Прохождение'), findsOneWidget);
    expect(find.text('Прогресс:'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(find.bySemanticsLabel('Всего в пути: 174 мин.'), findsOneWidget);
    expect(find.text('Остановки:'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Пауза'), findsOneWidget);
    expect(find.bySemanticsLabel('«Точка 1» отмечена'), findsOneWidget);
    expect(find.bySemanticsLabel('Отметить «Точка 2»'), findsOneWidget);
    expect(find.text('3,5 км'), findsWidgets);
    expect(find.bySemanticsLabel('Завершить маршрут'), findsOneWidget);
    // The separate «Пауза» button and the old «Готово» buttons are gone.
    expect(find.text('Готово'), findsNothing);

    // Leave the screen so its minute clock is disposed.
    GoRouter.of(tester.element(find.byType(RouteExecutionScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
  });
}
