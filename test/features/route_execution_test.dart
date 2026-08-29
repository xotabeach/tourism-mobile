import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourism_mobile/features/route_execution/application/route_execution_offline_coordinator.dart';
import 'package:tourism_mobile/features/route_execution/data/mock_route_execution_repository.dart';
import 'package:tourism_mobile/features/route_execution/data/route_execution_offline_store.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

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
}
