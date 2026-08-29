import 'package:tourism_mobile/features/route_execution/data/route_execution_offline_store.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution_repository.dart';

class RouteExecutionOfflineCoordinator {
  const RouteExecutionOfflineCoordinator(this.store, this.repository);

  final RouteExecutionOfflineStore store;
  final RouteExecutionRepository repository;

  Future<RouteExecution?> replayPending() async {
    var execution = await store.getSnapshot();
    for (final entry in await store.listOutbox()) {
      try {
        final updated = await switch (entry.action) {
          RouteExecutionAction.completeStop => repository.completeStop(
            entry.executionId,
            entry.stopId!,
          ),
          RouteExecutionAction.complete => repository.complete(
            entry.executionId,
          ),
          RouteExecutionAction.cancel => repository.cancel(entry.executionId),
        };
        execution = updated;
        await store.saveSnapshot(updated);
        await store.removeOutbox(entry.id);
      } on Object {
        await store.enqueue(entry.incrementAttempt());
        break;
      }
    }
    return execution;
  }

  Future<void> save(RouteExecution execution) => store.saveSnapshot(execution);

  Future<void> enqueue({
    required String executionId,
    required RouteExecutionAction action,
    String? stopId,
  }) {
    final id = '${executionId}_${DateTime.now().microsecondsSinceEpoch}';
    return store.enqueue(
      RouteExecutionOutboxEntry(
        id: id,
        executionId: executionId,
        stopId: stopId,
        action: action,
        createdAt: DateTime.now(),
      ),
    );
  }
}
