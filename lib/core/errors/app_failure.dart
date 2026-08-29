/// Typed failure for UI / providers. Never put tokens or passwords in [message].
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Network request failed']);
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'Resource not found']);
}

final class AuthFailure extends AppFailure {
  const AuthFailure([super.message = 'Authentication failed']);
}

/// A request the server refused for good: replaying it cannot succeed.
///
/// Used by the offline outbox to drop a queued action instead of retrying it
/// forever, for example when the run was already finished on another device.
final class RejectedFailure extends AppFailure {
  const RejectedFailure([super.message = 'Request rejected']);
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure([super.message = 'Unexpected error']);
}
