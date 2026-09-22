import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_offline_coordinator.dart';
import 'package:tourism_mobile/features/route_execution/data/route_execution_offline_store.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution_repository.dart';

class _Call {
  _Call(this.stopId, this.clientEventId, this.position);
  final String stopId;
  final String? clientEventId;
  final MarkPosition? position;
}

class _Repo implements RouteExecutionRepository {
  final calls = <_Call>[];
  Object? completeStopFailure;
  Object? startFailure;

  RouteExecution get execution => RouteExecution(
    id: 'real-1',
    routeId: 'r1',
    routeName: 'Маршрут',
    status: RouteExecutionStatus.active,
    startedAt: DateTime.utc(2026, 9, 20),
    totalStops: 2,
    completedStops: 0,
    requiredStops: 2,
    completedRequiredStops: 0,
    stops: const [
      RouteExecutionStop(
        id: 'srv-a',
        routeStopId: 'a',
        position: 1,
        placeName: 'A',
        isOptional: false,
      ),
      RouteExecutionStop(
        id: 'srv-b',
        routeStopId: 'b',
        position: 2,
        placeName: 'B',
        isOptional: false,
      ),
    ],
  );

  @override
  Future<RouteExecution> start(String routeId) async {
    final failure = startFailure;
    if (failure != null) throw failure;
    return execution;
  }

  @override
  Future<RouteExecution> completeStop(
    String executionId,
    String stopId, {
    String? clientEventId,
    DateTime? occurredAt,
    MarkPosition? position,
  }) async {
    calls.add(_Call(stopId, clientEventId, position));
    final failure = completeStopFailure;
    if (failure != null) throw failure;
    return execution;
  }

  @override
  Future<RouteExecution> uncompleteStop(
    String executionId,
    String stopId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async => execution;

  @override
  Future<List<RouteExecution>> list({int limit = 20, int offset = 0}) async =>
      const [];

  @override
  Future<RouteExecution?> getActive() async => execution;

  @override
  Future<RouteExecution> complete(
    String executionId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async => execution;

  @override
  Future<RouteExecution> cancel(
    String executionId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async => execution;

  @override
  Future<RouteExecution> pause(
    String executionId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async => execution;

  @override
  Future<RouteExecution> resume(
    String executionId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async => execution;
}

const _position = MarkPosition(lat: 44.5, lng: 34.1, accuracyMeters: 12);

RouteExecution _realSnapshot() => _Repo().execution;

void main() {
  test('a queued mark is delivered with its position and event id', () async {
    final store = MemoryRouteExecutionOfflineStore()
      ..snapshot = _realSnapshot();
    final repo = _Repo();
    final coordinator = RouteExecutionOfflineCoordinator(store, repo);

    await coordinator.enqueue(
      executionId: 'real-1',
      action: RouteExecutionAction.completeStop,
      stopId: 'srv-a',
      clientEventId: 'evt-1',
      occurredAt: DateTime.now(),
      position: _position,
    );
    await coordinator.replayPending();

    expect(repo.calls.single.clientEventId, 'evt-1');
    expect(repo.calls.single.position?.lat, 44.5);
    expect(await store.listOutbox(), isEmpty);
  });

  test('a position older than a day is not sent', () async {
    final store = MemoryRouteExecutionOfflineStore()
      ..snapshot = _realSnapshot();
    final repo = _Repo();
    final coordinator = RouteExecutionOfflineCoordinator(store, repo);

    await coordinator.enqueue(
      executionId: 'real-1',
      action: RouteExecutionAction.completeStop,
      stopId: 'srv-a',
      occurredAt: DateTime.now().subtract(const Duration(hours: 30)),
      position: _position,
    );
    await coordinator.replayPending();

    expect(repo.calls.single.position, isNull);
  });

  test('the position survives the outbox JSON round trip', () {
    final entry = RouteExecutionOutboxEntry(
      id: 'x',
      executionId: 'e',
      action: RouteExecutionAction.completeStop,
      createdAt: DateTime.utc(2026, 9, 20),
      position: _position,
    );
    final again = RouteExecutionOutboxEntry.fromJson(entry.toJson());
    expect(again.position?.accuracyMeters, 12);
    expect(again.incrementAttempt().position?.lng, 34.1);
  });

  test(
    'a dropped mark is remembered on the stop and its position is gone',
    () async {
      final store = MemoryRouteExecutionOfflineStore()
        ..snapshot = _realSnapshot();
      final repo = _Repo()..completeStopFailure = const RejectedFailure();
      final coordinator = RouteExecutionOfflineCoordinator(store, repo);

      await coordinator.enqueue(
        executionId: 'real-1',
        action: RouteExecutionAction.completeStop,
        stopId: 'srv-a',
        occurredAt: DateTime.now(),
        position: _position,
      );
      final result = await coordinator.replayPending();

      expect(await store.listOutbox(), isEmpty);
      expect(result!.stops.first.undelivered, isTrue);
      expect(result.stops.last.undelivered, isFalse);
      expect((await store.getSnapshot())!.stops.first.undelivered, isTrue);
    },
  );

  test('a fresh mark clears the undelivered note', () {
    final stop = _realSnapshot().stops.first.copyWith(undelivered: true);
    expect(stop.copyWith(undelivered: false).undelivered, isFalse);
  });

  test(
    'a local run replays each mark with its own event id and position',
    () async {
      final store = MemoryRouteExecutionOfflineStore();
      final repo = _Repo();
      final coordinator = RouteExecutionOfflineCoordinator(store, repo);
      const localId = 'local-1';
      store.snapshot = RouteExecution(
        id: localId,
        routeId: 'r1',
        routeName: 'Маршрут',
        status: RouteExecutionStatus.active,
        startedAt: DateTime.utc(2026, 9, 20),
        totalStops: 2,
        completedStops: 1,
        requiredStops: 2,
        completedRequiredStops: 1,
        stops: [
          RouteExecutionStop(
            id: 'a',
            routeStopId: 'a',
            position: 1,
            placeName: 'A',
            isOptional: false,
            completedAt: DateTime.utc(2026, 9, 20, 10),
          ),
          const RouteExecutionStop(
            id: 'b',
            routeStopId: 'b',
            position: 2,
            placeName: 'B',
            isOptional: false,
          ),
        ],
      );
      await store.enqueue(
        RouteExecutionOutboxEntry(
          id: '${localId}_start',
          executionId: localId,
          routeId: 'r1',
          action: RouteExecutionAction.start,
          createdAt: DateTime.utc(2026, 9, 20, 9),
        ),
      );
      await coordinator.enqueue(
        executionId: localId,
        action: RouteExecutionAction.completeStop,
        stopId: 'a',
        clientEventId: 'evt-a',
        occurredAt: DateTime.now(),
        position: _position,
      );

      await coordinator.replayPending();

      expect(repo.calls.single.stopId, 'srv-a');
      expect(repo.calls.single.clientEventId, 'evt-a');
      expect(repo.calls.single.position?.lat, 44.5);
      // The queued mark was consumed by the start replay, not delivered again.
      expect(await store.listOutbox(), isEmpty);
    },
  );

  test(
    'a blocked offline start keeps the queue and reports the deadline',
    () async {
      final store = MemoryRouteExecutionOfflineStore();
      final until = DateTime.utc(2026, 9, 21, 14, 30);
      final repo = _Repo()..startFailure = RouteStartBlockedFailure(until);
      DateTime? reported;
      final coordinator = RouteExecutionOfflineCoordinator(
        store,
        repo,
        onStartBlocked: (value) => reported = value,
      );
      await store.enqueue(
        RouteExecutionOutboxEntry(
          id: 'local-1_start',
          executionId: 'local-1',
          routeId: 'r1',
          action: RouteExecutionAction.start,
          createdAt: DateTime.utc(2026, 9, 20, 9),
        ),
      );

      await coordinator.replayPending();
      await coordinator.replayPending();

      expect(reported, until);
      final kept = await store.listOutbox();
      expect(kept, hasLength(1));
      expect(kept.single.attempts, 0);
    },
  );
}
