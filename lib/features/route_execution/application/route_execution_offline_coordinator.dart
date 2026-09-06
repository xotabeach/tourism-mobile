import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/client_event_id.dart';
import 'package:tourism_mobile/features/route_execution/data/route_execution_offline_store.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution_repository.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

class RouteExecutionOfflineCoordinator {
  const RouteExecutionOfflineCoordinator(this.store, this.repository);

  /// After this many failed deliveries the entry is dropped: keeping it would
  /// block every later action in the queue without ever succeeding.
  static const maxAttempts = 5;

  /// Marks a [RouteExecution.id] as client-generated and not-yet-synced —
  /// there is a pending [RouteExecutionAction.start] outbox entry for it.
  /// `start_execution` on the backend is idempotent per (user, route), so
  /// replaying it is always safe; this prefix only distinguishes "no server
  /// id exists yet" for the screen and for [replayPending]'s reconciliation.
  static const localExecutionPrefix = 'local-';

  final RouteExecutionOfflineStore store;
  final RouteExecutionRepository repository;

  /// Begin a route entirely offline: builds a local-only execution from the
  /// downloaded route's own stops, saves it as the snapshot, and queues a
  /// single [RouteExecutionAction.start] to reconcile once connectivity
  /// returns. Any stop completions made while still offline are applied to
  /// this local snapshot directly (see [route_execution_screen.dart]) rather
  /// than queued individually — [replayPending] replays them against the
  /// real execution in one pass, once it exists.
  Future<RouteExecution> startOffline(RouteDetail route) async {
    final localId = '$localExecutionPrefix${DateTime.now().microsecondsSinceEpoch}';
    final requiredStops = route.stops.where((stop) => !stop.isOptional).length;
    final execution = RouteExecution(
      id: localId,
      routeId: route.id,
      routeName: route.name,
      routeCoverUrl: route.coverImageUrl,
      status: RouteExecutionStatus.active,
      startedAt: DateTime.now(),
      totalStops: route.stops.length,
      completedStops: 0,
      requiredStops: requiredStops,
      completedRequiredStops: 0,
      stops: [
        for (final stop in route.stops)
          RouteExecutionStop(
            id: stop.id,
            routeStopId: stop.id,
            placeId: stop.placeId,
            position: stop.position,
            placeName: stop.placeName,
            isOptional: stop.isOptional,
            lat: stop.lat,
            lng: stop.lng,
          ),
      ],
    );
    await store.saveSnapshot(execution);
    await store.enqueue(
      RouteExecutionOutboxEntry(
        id: '${localId}_start',
        executionId: localId,
        routeId: route.id,
        clientEventId: newClientEventId(),
        action: RouteExecutionAction.start,
        createdAt: execution.startedAt,
      ),
    );
    return execution;
  }

  Future<RouteExecution?> replayPending() async {
    var execution = await store.getSnapshot();
    for (final entry in await store.listOutbox()) {
      if (entry.action == RouteExecutionAction.completeStop &&
          entry.stopId == null) {
        await store.removeOutbox(entry.id);
        continue;
      }
      try {
        final updated = entry.action == RouteExecutionAction.start
            ? await _deliverStart(entry, execution)
            : await _deliver(entry);
        execution = updated;
        await store.saveSnapshot(updated);
        await store.removeOutbox(entry.id);
      } on NetworkFailure {
        // Still offline: keep the queue intact and wait for the next attempt.
        await store.enqueue(entry.incrementAttempt());
        break;
      } on RejectedFailure {
        // The run moved on elsewhere; replaying this action cannot succeed.
        await store.removeOutbox(entry.id);
      } on NotFoundFailure {
        await store.removeOutbox(entry.id);
      } on Object {
        // An action that keeps failing must not block the rest of the queue.
        final attempted = entry.incrementAttempt();
        if (attempted.attempts >= maxAttempts) {
          await store.removeOutbox(entry.id);
          continue;
        }
        await store.enqueue(attempted);
        break;
      }
    }
    return execution;
  }

  Future<void> save(RouteExecution execution) => store.saveSnapshot(execution);

  /// [clientEventId] should be the key of the request that failed, so a
  /// mutation the server already applied is deduped rather than repeated.
  Future<void> enqueue({
    required String executionId,
    required RouteExecutionAction action,
    String? stopId,
    String? clientEventId,
    DateTime? occurredAt,
  }) {
    final id = '${executionId}_${DateTime.now().microsecondsSinceEpoch}';
    return store.enqueue(
      RouteExecutionOutboxEntry(
        id: id,
        executionId: executionId,
        stopId: stopId,
        clientEventId: clientEventId ?? newClientEventId(),
        action: action,
        createdAt: occurredAt ?? DateTime.now(),
      ),
    );
  }

  /// Starts the route for real, then catches the now-real execution up to
  /// whatever was recorded against the local snapshot while offline —
  /// completed stops (matched by the stable `routeStopId`, since the local
  /// and server stop ids differ) and a final complete/cancel, in that order.
  Future<RouteExecution> _deliverStart(
    RouteExecutionOutboxEntry entry,
    RouteExecution? localSnapshot,
  ) async {
    final routeId = entry.routeId;
    if (routeId == null) {
      throw const RejectedFailure('Missing route id for an offline start');
    }
    var real = await repository.start(routeId);
    final local = localSnapshot;
    if (local == null || local.id != entry.executionId) {
      return real;
    }
    for (final localStop in local.stops.where((stop) => stop.isCompleted)) {
      final match = real.stops
          .where((stop) => stop.routeStopId == localStop.routeStopId)
          .firstOrNull;
      if (match != null && !match.isCompleted) {
        real = await repository.completeStop(
          real.id,
          match.id,
          occurredAt: localStop.completedAt,
        );
      }
    }
    if (local.status == RouteExecutionStatus.completed) {
      real = await repository.complete(
        real.id,
        occurredAt: local.completedAt,
      );
    } else if (local.status == RouteExecutionStatus.cancelled) {
      real = await repository.cancel(
        real.id,
        occurredAt: local.cancelledAt,
      );
    } else if (local.status == RouteExecutionStatus.paused) {
      real = await repository.pause(real.id);
    }
    return real;
  }

  Future<RouteExecution> _deliver(RouteExecutionOutboxEntry entry) {
    return switch (entry.action) {
      RouteExecutionAction.start => throw StateError(
        'start is handled by _deliverStart',
      ),
      RouteExecutionAction.completeStop => repository.completeStop(
        entry.executionId,
        entry.stopId ?? '',
        clientEventId: entry.clientEventId,
        occurredAt: entry.createdAt,
      ),
      RouteExecutionAction.complete => repository.complete(
        entry.executionId,
        clientEventId: entry.clientEventId,
        occurredAt: entry.createdAt,
      ),
      RouteExecutionAction.cancel => repository.cancel(
        entry.executionId,
        clientEventId: entry.clientEventId,
        occurredAt: entry.createdAt,
      ),
      RouteExecutionAction.pause => repository.pause(
        entry.executionId,
        clientEventId: entry.clientEventId,
        occurredAt: entry.createdAt,
      ),
      RouteExecutionAction.resume => repository.resume(
        entry.executionId,
        clientEventId: entry.clientEventId,
        occurredAt: entry.createdAt,
      ),
    };
  }
}
