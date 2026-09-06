import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True when the device reports *some* network interface as reachable.
///
/// This is a signal, not a guarantee — a Wi-Fi network with no internet
/// still counts as "connected" here. Every real API call has its own
/// [NetworkFailure] handling regardless; this provider only drives proactive
/// UI (an offline banner, switching a screen to its cached data source)
/// before the user even attempts a request.
final connectivityStatusProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  final connectivity = Connectivity();
  return connectivity.onConnectivityChanged.startWith(
    connectivity.checkConnectivity(),
  );
});

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((result) => result != ConnectivityResult.none);

/// Defaults to `true` (online) while the initial check is still in flight —
/// screens should not flash an offline banner during normal startup.
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider);
  return status.maybeWhen(data: _isOnline, orElse: () => true);
});

extension on Stream<List<ConnectivityResult>> {
  /// Emits [initial]'s eventual result first, then this stream — avoids a
  /// dependency on rxdart for one `startWith`.
  Stream<List<ConnectivityResult>> startWith(
    Future<List<ConnectivityResult>> initial,
  ) async* {
    yield await initial;
    yield* this;
  }
}
