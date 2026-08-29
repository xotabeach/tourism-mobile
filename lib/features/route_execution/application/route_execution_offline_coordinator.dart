import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/client_event_id.dart';
import 'package:tourism_mobile/features/route_execution/data/route_execution_offline_store.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution_repository.dart';

class RouteExecutionOfflineCoordinator {
  const RouteExecutionOfflineCoordinator(this.store, this.repository);

  /// After this many failed deliveries the entry is dropped: keeping it would
  /// block every later action in the queue without ever succeeding.
  static const maxAttempts = 5;

  final RouteExecutionOfflineStore store;
  final RouteExecutionRepository repository;

  Future<RouteExecution?> replayPending() async {
    var execution = await store.getSnapshot();
    for (final entry in await store.listOutbox()) {
      if (entry.action == RouteExecutionAction.completeStop &&
          entry.stopId == null) {
        await store.removeOutbox(entry.id);
        continue;
      }
      try {
        final updated = await _deliver(entry);
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

  Future<RouteExecution> _deliver(RouteExecutionOutboxEntry entry) {
    return switch (entry.action) {
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
    };
  }
}
