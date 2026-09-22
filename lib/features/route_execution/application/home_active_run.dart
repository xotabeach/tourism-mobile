import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_providers.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

/// A run in progress, as the home card draws it (FRONTEND-34, spec 13).
class HomeActiveRun {
  const HomeActiveRun({required this.run, required this.offline});

  final RouteExecution run;

  /// Read from the device snapshot because the server could not be reached:
  /// the card says the data may be out of date.
  final bool offline;

  /// No mark, start or resume for a day (spec 13, D6).
  bool isStale(DateTime now) =>
      now.difference(run.lastActivity) > const Duration(hours: 24);
}

/// The run the home card shows instead of the «Подбери маршрут» banner, or
/// null for the banner.
///
/// Marks queued offline go out first, so a run finished away from the
/// network is not shown as still going. Without a network the device
/// snapshot stands in, but only for a run still active or paused — a
/// finished snapshot is never cleared and must not bring the card back. An
/// auth error is not a network error: no card then.
final homeActiveRunProvider = FutureProvider.autoDispose<HomeActiveRun?>((
  ref,
) async {
  if (!ref.watch(sessionProvider.select((s) => s.isAuthenticated))) {
    return null;
  }
  final repository = ref.watch(routeExecutionRepositoryProvider);
  try {
    await ref.read(routeExecutionOfflineCoordinatorProvider).replayPending();
  } on Object {
    // Replay failing must not hide the card; the run screen retries it.
  }
  try {
    final run = await repository.getActive();
    return run != null && _inProgress(run)
        ? HomeActiveRun(run: run, offline: false)
        : null;
  } on NetworkFailure {
    final snapshot = await ref
        .read(routeExecutionOfflineStoreProvider)
        .getSnapshot();
    return snapshot != null && _inProgress(snapshot)
        ? HomeActiveRun(run: snapshot, offline: true)
        : null;
  }
});

bool _inProgress(RouteExecution run) =>
    run.status == RouteExecutionStatus.active ||
    run.status == RouteExecutionStatus.paused;
