/// Typed failure for UI / providers. Never put tokens or passwords in [message].
sealed class AppFailure implements Exception {
  const AppFailure(this.message, [this.code, this.details]);

  final String message;

  /// The API envelope's `error.code`, when the failure came from one. Lets a
  /// caller react to a specific refusal (a chat that filled up, say) without
  /// matching on human-readable text that translation would break.
  final String? code;

  /// The envelope's `error.details`, when it carried a map. Optional extras
  /// only (a `blocked_until` timestamp, say); never rely on it being present.
  final Map<String, Object?>? details;

  @override
  String toString() => message;
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Network request failed', super.code]);

  /// [code] of a request that reached no answer in time, as opposed to one
  /// that found no connection at all.
  static const timeoutCode = 'timeout';
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'Resource not found', super.code]);
}

final class AuthFailure extends AppFailure {
  const AuthFailure([super.message = 'Authentication failed', super.code]);
}

/// A request the server refused for good: replaying it cannot succeed.
///
/// Used by the offline outbox to drop a queued action instead of retrying it
/// forever, for example when the run was already finished on another device.
final class RejectedFailure extends AppFailure {
  const RejectedFailure([super.message = 'Request rejected', super.code]);
}

/// The server refuses to start new routes for this account for a while
/// (anti-fraud). Not an [AuthFailure]: the session is fine and must stay.
final class RouteStartBlockedFailure extends AppFailure {
  const RouteStartBlockedFailure(
    this.blockedUntil, [
    super.message = 'Route start is temporarily unavailable',
    super.code = 'route_start_blocked',
  ]);

  final DateTime? blockedUntil;
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure([super.message = 'Unexpected error', super.code]);
}
