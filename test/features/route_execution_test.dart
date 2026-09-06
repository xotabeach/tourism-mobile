import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_offline_coordinator.dart';
import 'package:tourism_mobile/features/route_execution/data/mock_route_execution_repository.dart';
import 'package:tourism_mobile/features/route_execution/data/route_execution_offline_store.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution_repository.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

void main() {
  test('parses execution progress and immutable routing facts', () {
    final execution = RouteExecution.fromJson({
      'id': 'execution-1',
      'route_id': 'route-1',
      'route_name': 'Южный берег',
      'status': 'active',
      'started_at': '2026-08-29T09:00:00Z',
      'total_stops': 2,
      'completed_stops': 1,
      'required_stops': 2,
      'completed_required_stops': 1,
      'routing': {
        'provider': '2gis',
        'quality_status': 'verified_with_warnings',
        'warnings': ['check_weather'],
        'distance_meters': 4200,
      },
      'stops': [
        {
          'id': 'stop-1',
          'position': 1,
          'place_name': 'Ливадийский дворец',
          'is_optional': false,
          'completed_at': '2026-08-29T09:30:00Z',
        },
        {
          'id': 'stop-2',
          'position': 2,
          'place_name': 'Набережная',
          'is_optional': false,
          'completed_at': null,
        },
      ],
    });

    expect(execution.progress, .5);
    expect(execution.isActive, isTrue);
    expect(execution.routing?.provider, '2gis');
    expect(execution.routing?.distanceMeters, 4200);
    expect(execution.stops.first.isCompleted, isTrue);
    expect(execution.stops.last.isCompleted, isFalse);
  });

  test('mock repository resumes one active route and can cancel it', () async {
    final repository = MockRouteExecutionRepository();

    final started = await repository.start('route-1');
    final resumed = await repository.start('route-1');
    final cancelled = await repository.cancel(started.id);

    expect(resumed.id, started.id);
    expect(cancelled.status, RouteExecutionStatus.cancelled);
    expect(cancelled.cancelledAt, isNotNull);
  });

  test('mock repository exposes finished executions in history', () async {
    final repository = MockRouteExecutionRepository();

    final completed = await repository.start('route-completed');
    await repository.complete(completed.id);
    final cancelled = await repository.start('route-cancelled');
    await repository.cancel(cancelled.id);

    final history = await repository.list();
    expect(history, hasLength(2));
    expect(history[0].status, RouteExecutionStatus.cancelled);
    expect(history[1].status, RouteExecutionStatus.completed);
  });

  test(
    'offline coordinator replays pending action and clears the outbox',
    () async {
      final repository = MockRouteExecutionRepository();
      final execution = await repository.start('route-offline');
      final store = MemoryRouteExecutionOfflineStore();
      await store.saveSnapshot(execution);
      await store.enqueue(
        RouteExecutionOutboxEntry(
          id: 'event-1',
          executionId: execution.id,
          action: RouteExecutionAction.complete,
          createdAt: DateTime.utc(2026, 8, 29),
        ),
      );

      final updated = await RouteExecutionOfflineCoordinator(
        store,
        repository,
      ).replayPending();

      expect(updated?.status, RouteExecutionStatus.completed);
      expect(await store.listOutbox(), isEmpty);
      expect(
        (await store.getSnapshot())?.status,
        RouteExecutionStatus.completed,
      );
    },
  );

  test(
    'shared preferences store persists snapshot and pending action',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesRouteExecutionOfflineStore();
      final repository = MockRouteExecutionRepository();
      final execution = await repository.start('route-persisted');
      await store.saveSnapshot(execution);
      await store.enqueue(
        RouteExecutionOutboxEntry(
          id: 'event-persisted',
          executionId: execution.id,
          action: RouteExecutionAction.cancel,
          createdAt: DateTime.utc(2026, 8, 29),
        ),
      );

      expect((await store.getSnapshot())?.routeId, 'route-persisted');
      expect(
        (await store.listOutbox()).single.action,
        RouteExecutionAction.cancel,
      );
      await store.clear();
      expect(await store.getSnapshot(), isNull);
      expect(await store.listOutbox(), isEmpty);
    },
  );

  test('queued action carries an idempotency key and its own moment', () async {
    final repository = MockRouteExecutionRepository();
    final execution = await repository.start('route-keyed');
    final store = MemoryRouteExecutionOfflineStore();
    final coordinator = RouteExecutionOfflineCoordinator(store, repository);
    final occurredAt = DateTime.utc(2026, 8, 29, 8, 15);

    await coordinator.enqueue(
      executionId: execution.id,
      action: RouteExecutionAction.complete,
      occurredAt: occurredAt,
    );

    final entry = (await store.listOutbox()).single;
    expect(entry.clientEventId, isNotNull);
    expect(entry.clientEventId, hasLength(36));
    expect(entry.createdAt, occurredAt);

    final replayed = await coordinator.replayPending();
    expect(replayed?.completedAt, occurredAt);
    expect(await store.listOutbox(), isEmpty);
  });

  test('a rejected action is dropped instead of blocking the queue', () async {
    final repository = _StubExecutionRepository(
      failures: {'stop-blocked': const RejectedFailure('run already finished')},
    );
    final store = MemoryRouteExecutionOfflineStore();
    final coordinator = RouteExecutionOfflineCoordinator(store, repository);
    for (final stopId in ['stop-blocked', 'stop-next']) {
      await coordinator.enqueue(
        executionId: 'execution-1',
        action: RouteExecutionAction.completeStop,
        stopId: stopId,
      );
    }

    await coordinator.replayPending();

    expect(await store.listOutbox(), isEmpty);
    expect(repository.delivered, ['stop-blocked', 'stop-next']);
  });

  test('offline delivery keeps the queue and counts the attempt', () async {
    final repository = _StubExecutionRepository(
      failures: {'stop-offline': const NetworkFailure()},
    );
    final store = MemoryRouteExecutionOfflineStore();
    final coordinator = RouteExecutionOfflineCoordinator(store, repository);
    await coordinator.enqueue(
      executionId: 'execution-1',
      action: RouteExecutionAction.completeStop,
      stopId: 'stop-offline',
    );

    await coordinator.replayPending();

    expect((await store.listOutbox()).single.attempts, 1);
  });

  test(
    'starting fully offline reconciles local stop completions and the '
    'final status against the real execution once online',
    () async {
      const route = RouteDetail(
        id: 'route-offline-start',
        name: 'Оффлайн маршрут',
        slug: 'offline-route',
        shortDescription: 'Описание',
        stopsCount: 2,
        description: 'Подробное описание',
        stops: [
          RouteStop(
            id: 'stop-a',
            position: 1,
            placeId: 'place-a',
            placeName: 'Точка A',
            placeSlug: 'point-a',
          ),
          RouteStop(
            id: 'stop-b',
            position: 2,
            placeId: 'place-b',
            placeName: 'Точка B',
            placeSlug: 'point-b',
            isOptional: true,
          ),
        ],
      );
      final repository = _StartReconcileRepository();
      final store = MemoryRouteExecutionOfflineStore();
      final coordinator = RouteExecutionOfflineCoordinator(store, repository);

      final local = await coordinator.startOffline(route);
      expect(
        local.id,
        startsWith(RouteExecutionOfflineCoordinator.localExecutionPrefix),
      );
      expect((await store.listOutbox()).single.action, RouteExecutionAction.start);

      // The user completes the one required stop and finishes the route —
      // all of this only ever touches the local snapshot (no separate
      // outbox entries), matching what the screen does.
      final completed = local.copyWith(
        status: RouteExecutionStatus.completed,
        completedAt: DateTime.utc(2026, 9, 6, 12),
        completedStops: 1,
        completedRequiredStops: 1,
        stops: [
          for (final stop in local.stops)
            stop.id == 'stop-a'
                ? stop.copyWith(completedAt: DateTime.utc(2026, 9, 6, 11, 55))
                : stop,
        ],
      );
      await store.saveSnapshot(completed);

      final result = await coordinator.replayPending();

      expect(await store.listOutbox(), isEmpty);
      expect(repository.startedRouteIds, ['route-offline-start']);
      expect(repository.completedStopServerIds, ['srv-stop-a']);
      expect(repository.completedExecutionIds, ['srv-execution']);
      expect(result?.id, 'srv-execution');
      expect(result?.status, RouteExecutionStatus.completed);
      expect((await store.getSnapshot())?.id, 'srv-execution');
    },
  );

  test('an action that keeps failing is dropped after the last try', () async {
    final repository = _StubExecutionRepository(
      failures: {'stop-broken': StateError('server said no')},
    );
    final store = MemoryRouteExecutionOfflineStore();
    final coordinator = RouteExecutionOfflineCoordinator(store, repository);
    await coordinator.enqueue(
      executionId: 'execution-1',
      action: RouteExecutionAction.completeStop,
      stopId: 'stop-broken',
    );

    for (
      var attempt = 0;
      attempt < RouteExecutionOfflineCoordinator.maxAttempts;
      attempt++
    ) {
      await coordinator.replayPending();
    }

    expect(await store.listOutbox(), isEmpty);
  });
}

/// Repository that records deliveries and fails for chosen stop ids.
class _StubExecutionRepository implements RouteExecutionRepository {
  _StubExecutionRepository({required this.failures});

  final Map<String, Object> failures;
  final delivered = <String>[];

  RouteExecution get _execution => RouteExecution(
    id: 'execution-1',
    routeId: 'route-1',
    routeName: 'Тестовый маршрут',
    status: RouteExecutionStatus.active,
    startedAt: DateTime.utc(2026, 8, 29, 7),
    totalStops: 2,
    completedStops: 1,
    requiredStops: 2,
    completedRequiredStops: 1,
    stops: const [],
  );

  @override
  Future<RouteExecution> completeStop(
    String executionId,
    String stopId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async {
    delivered.add(stopId);
    final failure = failures[stopId];
    if (failure != null) throw failure;
    return _execution;
  }

  @override
  Future<RouteExecution> complete(
    String executionId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async => _execution;

  @override
  Future<RouteExecution> cancel(
    String executionId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async => _execution;

  @override
  Future<RouteExecution?> getActive() async => _execution;

  @override
  Future<List<RouteExecution>> list({int limit = 20, int offset = 0}) async =>
      const [];

  @override
  Future<RouteExecution> start(String routeId) async => _execution;
}

/// Simulates the server side of an offline-start reconciliation: `start`
/// returns a fresh execution whose stops carry the *server's own* ids while
/// still exposing the original `routeStopId`, exactly like the real backend.
class _StartReconcileRepository implements RouteExecutionRepository {
  final startedRouteIds = <String>[];
  final completedStopServerIds = <String>[];
  final completedExecutionIds = <String>[];

  @override
  Future<RouteExecution> start(String routeId) async {
    startedRouteIds.add(routeId);
    return RouteExecution(
      id: 'srv-execution',
      routeId: routeId,
      routeName: 'Оффлайн маршрут',
      status: RouteExecutionStatus.active,
      startedAt: DateTime.utc(2026, 9, 6, 11, 50),
      totalStops: 2,
      completedStops: 0,
      requiredStops: 1,
      completedRequiredStops: 0,
      stops: const [
        RouteExecutionStop(
          id: 'srv-stop-a',
          routeStopId: 'stop-a',
          position: 1,
          placeName: 'Точка A',
          isOptional: false,
        ),
        RouteExecutionStop(
          id: 'srv-stop-b',
          routeStopId: 'stop-b',
          position: 2,
          placeName: 'Точка B',
          isOptional: true,
        ),
      ],
    );
  }

  @override
  Future<RouteExecution> completeStop(
    String executionId,
    String stopId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async {
    completedStopServerIds.add(stopId);
    return RouteExecution(
      id: executionId,
      routeId: 'route-offline-start',
      routeName: 'Оффлайн маршрут',
      status: RouteExecutionStatus.active,
      startedAt: DateTime.utc(2026, 9, 6, 11, 50),
      totalStops: 2,
      completedStops: 1,
      requiredStops: 1,
      completedRequiredStops: 1,
      stops: [
        RouteExecutionStop(
          id: 'srv-stop-a',
          routeStopId: 'stop-a',
          position: 1,
          placeName: 'Точка A',
          isOptional: false,
          completedAt: occurredAt,
        ),
        const RouteExecutionStop(
          id: 'srv-stop-b',
          routeStopId: 'stop-b',
          position: 2,
          placeName: 'Точка B',
          isOptional: true,
        ),
      ],
    );
  }

  @override
  Future<RouteExecution> complete(
    String executionId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async {
    completedExecutionIds.add(executionId);
    return RouteExecution(
      id: executionId,
      routeId: 'route-offline-start',
      routeName: 'Оффлайн маршрут',
      status: RouteExecutionStatus.completed,
      startedAt: DateTime.utc(2026, 9, 6, 11, 50),
      completedAt: occurredAt,
      totalStops: 2,
      completedStops: 1,
      requiredStops: 1,
      completedRequiredStops: 1,
      stops: const [],
    );
  }

  @override
  Future<RouteExecution> cancel(
    String executionId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async => throw UnimplementedError();

  @override
  Future<RouteExecution?> getActive() async => null;

  @override
  Future<List<RouteExecution>> list({int limit = 20, int offset = 0}) async =>
      const [];
}
