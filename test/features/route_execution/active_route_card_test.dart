import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/route_execution/application/home_active_run.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_providers.dart';
import 'package:tourism_mobile/features/route_execution/data/mock_route_execution_repository.dart';
import 'package:tourism_mobile/features/route_execution/data/route_execution_offline_store.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/active_route_card.dart';

import '../../support/test_overrides.dart';

RouteExecution _run({
  RouteExecutionStatus status = RouteExecutionStatus.active,
  DateTime? startedAt,
  DateTime? pausedAt,
  DateTime? lastActivityAt,
  int pausedDurationSeconds = 0,
}) {
  final start =
      startedAt ?? DateTime.now().subtract(const Duration(minutes: 78));
  return RouteExecution(
    id: 'run-1',
    routeId: 'route-1',
    routeName: 'Ласточкино гнездо и царская тропа',
    status: status,
    startedAt: start,
    pausedAt: pausedAt,
    lastActivityAt: lastActivityAt,
    pausedDurationSeconds: pausedDurationSeconds,
    totalStops: 7,
    completedStops: 3,
    requiredStops: 7,
    completedRequiredStops: 3,
    routing: const RouteExecutionRouting(distanceMeters: 4200),
    stops: [
      for (var i = 0; i < 7; i++)
        RouteExecutionStop(
          id: 's$i',
          position: i + 1,
          placeName: i == 3
              ? 'Смотровая площадка у Аврориной скалы'
              : 'Точка ${i + 1}',
          isOptional: false,
          legDistanceMeters: i == 0 ? null : 600,
          completedAt: i < 3 ? start.add(Duration(minutes: 10 * i)) : null,
        ),
    ],
  );
}

class _Repo extends MockRouteExecutionRepository {
  _Repo({this.active, this.failure});

  final RouteExecution? active;
  final Object? failure;

  @override
  Future<RouteExecution?> getActive() async {
    if (failure != null) throw failure!;
    return active;
  }
}

Future<HomeActiveRun?> _load({
  required RouteExecution? active,
  Object? failure,
  RouteExecution? snapshot,
  bool signedIn = true,
}) async {
  final store = MemoryRouteExecutionOfflineStore();
  if (snapshot != null) await store.saveSnapshot(snapshot);
  final container = ProviderContainer(
    overrides: [
      ...testSessionOverrides(onboardingCompleted: signedIn),
      routeExecutionRepositoryProvider.overrideWithValue(
        _Repo(active: active, failure: failure),
      ),
      routeExecutionOfflineStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return container.read(homeActiveRunProvider.future);
}

void main() {
  group('home active run', () {
    test('a run in progress on the server shows the card', () async {
      final state = await _load(active: _run());
      expect(state?.run.id, 'run-1');
      expect(state?.offline, isFalse);
    });

    test('no run on the server keeps the banner', () async {
      expect(await _load(active: null), isNull);
    });

    test('without a network the device snapshot stands in', () async {
      final state = await _load(
        active: null,
        failure: const NetworkFailure('offline'),
        snapshot: _run(status: RouteExecutionStatus.paused),
      );
      expect(state?.offline, isTrue);
      expect(state?.run.status, RouteExecutionStatus.paused);
    });

    test('a finished snapshot never brings the card back', () async {
      final state = await _load(
        active: null,
        failure: const NetworkFailure('offline'),
        snapshot: _run(status: RouteExecutionStatus.completed),
      );
      expect(state, isNull);
    });

    test('a guest has no card and asks nothing', () async {
      expect(await _load(active: _run(), signedIn: false), isNull);
    });
  });

  group('elapsed time', () {
    test('stands still while paused', () {
      final start = DateTime(2026, 9, 22, 10);
      final run = _run(
        status: RouteExecutionStatus.paused,
        startedAt: start,
        pausedAt: start.add(const Duration(minutes: 50)),
        pausedDurationSeconds: 600,
      );
      expect(run.elapsed(start.add(const Duration(hours: 5))).inMinutes, 40);
    });
  });

  group('card', () {
    Future<void> pump(WidgetTester tester, HomeActiveRun state) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(393, 400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: testSessionOverrides(onboardingCompleted: true),
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: ActiveRouteCard(state: state),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a run in progress: status, time, progress, next stop', (
      tester,
    ) async {
      await pump(tester, HomeActiveRun(run: _run(), offline: false));
      expect(find.text('Идёт прохождение'), findsOneWidget);
      expect(find.text('78 мин'), findsOneWidget);
      expect(find.text('Ласточкино гнездо и царская тропа'), findsOneWidget);
      // Planned legs up to the marked stops out of the whole route.
      expect(find.text('3 из 7 точек • 1,2 из 4,2 км'), findsOneWidget);
      expect(
        find.text('Дальше: Смотровая площадка у Аврориной скалы'),
        findsOneWidget,
      );
    });

    testWidgets('paused, stale and offline runs say so', (tester) async {
      await pump(
        tester,
        HomeActiveRun(
          run: _run(
            status: RouteExecutionStatus.paused,
            pausedAt: DateTime.now(),
          ),
          offline: false,
        ),
      );
      expect(find.text('На паузе'), findsOneWidget);

      await pump(
        tester,
        HomeActiveRun(
          run: _run(
            startedAt: DateTime.now().subtract(const Duration(days: 2)),
            lastActivityAt: DateTime.now().subtract(const Duration(hours: 30)),
          ),
          offline: false,
        ),
      );
      expect(find.text('Неактивен более суток'), findsOneWidget);

      await pump(tester, HomeActiveRun(run: _run(), offline: true));
      expect(find.text('Нет сети'), findsOneWidget);
    });
  });
}
