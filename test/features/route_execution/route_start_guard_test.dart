import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_providers.dart';
import 'package:tourism_mobile/features/route_execution/data/mock_route_execution_repository.dart';
import 'package:tourism_mobile/features/route_execution/data/route_execution_offline_store.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/route_execution_screen.dart';
import 'package:tourism_mobile/features/routes/application/offline_routes_provider.dart';
import 'package:tourism_mobile/features/routes/data/mock_routes_repository.dart';
import 'package:tourism_mobile/features/routes/data/offline_route_store.dart';
import 'package:tourism_mobile/routing/app_router.dart';

import '../../support/test_overrides.dart';

const _routeId = 'route-south-coast';

RouteExecution _run({required String routeId, required String name}) =>
    RouteExecution(
      id: 'other-run',
      routeId: routeId,
      routeName: name,
      status: RouteExecutionStatus.paused,
      startedAt: DateTime.now().subtract(const Duration(hours: 1)),
      totalStops: 2,
      completedStops: 1,
      requiredStops: 2,
      completedRequiredStops: 1,
      stops: const [],
    );

/// No connection at all: every call fails like it would in airplane mode.
class _Offline extends MockRouteExecutionRepository {
  var starts = 0;

  @override
  Future<RouteExecution?> getActive() async => throw const NetworkFailure();

  @override
  Future<RouteExecution> start(String routeId) async {
    starts += 1;
    throw const NetworkFailure();
  }
}

/// Another device starts a run between the screen's check and its start.
class _Raced extends MockRouteExecutionRepository {
  var checks = 0;

  @override
  Future<RouteExecution?> getActive() async {
    checks += 1;
    return checks == 1
        ? null
        : _run(routeId: 'route-other', name: 'Ялта: набережная');
  }

  @override
  Future<RouteExecution> start(String routeId) async =>
      throw const UnexpectedFailure(
        'Finish or cancel the active route first',
        activeRunConflictCode,
      );
}

Future<void> _open(
  WidgetTester tester,
  MockRouteExecutionRepository repo, {
  RouteExecutionOfflineStore? runs,
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
  final downloaded = MemoryOfflineRouteStore();
  await tester.runAsync(
    () async =>
        downloaded.save(await MockRoutesRepository().getRoute(_routeId)),
  );
  await pumpTourismAppAtHome(
    tester,
    overrides: [
      routeExecutionRepositoryProvider.overrideWithValue(repo),
      offlineRouteStoreProvider.overrideWithValue(downloaded),
      if (runs != null)
        routeExecutionOfflineStoreProvider.overrideWithValue(runs),
    ],
  );
  unawaited(
    GoRouter.of(
      tester.element(find.byType(HomeScreen)),
    ).pushNamed(AppRouteNames.routeExecution, pathParameters: {'id': _routeId}),
  );
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('offline, a run of another route blocks a new start', (
    tester,
  ) async {
    final runs = MemoryRouteExecutionOfflineStore()
      ..snapshot = _run(routeId: 'route-other', name: 'Ялта: набережная');
    await _open(tester, _Offline(), runs: runs);

    expect(find.text('Сначала заверши текущий маршрут'), findsOneWidget);
    expect(find.text('Сейчас проходится «Ялта: набережная»'), findsOneWidget);
    expect(
      runs.snapshot?.id,
      'other-run',
      reason: 'the run is not overwritten',
    );
    expect(runs.entries, isEmpty, reason: 'no start is queued');
  });

  testWidgets('offline, an unsent start of the last run blocks a second one', (
    tester,
  ) async {
    final runs = MemoryRouteExecutionOfflineStore();
    await tester.runAsync(
      () => runs.enqueue(
        RouteExecutionOutboxEntry(
          id: 'local-1_start',
          executionId: 'local-1',
          routeId: 'route-other',
          clientEventId: 'e1',
          action: RouteExecutionAction.start,
          createdAt: DateTime.now(),
        ),
      ),
    );
    await _open(tester, _Offline(), runs: runs);

    expect(find.text(offlineStartWaitsMessage), findsOneWidget);
    expect(runs.entries.length, 1, reason: 'still only the first start');
  });

  testWidgets('offline with nothing in progress, the route starts locally', (
    tester,
  ) async {
    final runs = MemoryRouteExecutionOfflineStore();
    await _open(tester, _Offline(), runs: runs);

    expect(find.text('Сначала заверши текущий маршрут'), findsNothing);
    expect(runs.snapshot?.routeId, _routeId);
    expect(
      runs.entries.values.where((e) => e.action == RouteExecutionAction.start),
      hasLength(1),
    );
  });

  testWidgets('a start lost to another device names the run in the way', (
    tester,
  ) async {
    final repo = _Raced();
    await _open(tester, repo, runs: MemoryRouteExecutionOfflineStore());

    expect(find.text('Сначала заверши текущий маршрут'), findsOneWidget);
    expect(find.text('Сейчас проходится «Ялта: набережная»'), findsOneWidget);
    expect(find.text('Маршрут нельзя начать сейчас'), findsNothing);
  });
}
