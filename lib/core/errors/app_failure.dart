/// Typed failure for UI / providers. Never put tokens or passwords in [message].
sealed class AppFailure implements Exception {
  const AppFailure(this.message, [this.code]);

  final String message;

  /// The API envelope's `error.code`, when the failure came from one. Lets a
  /// caller react to a specific refusal (a chat that filled up, say) without
  /// matching on human-readable text that translation would break.
  final String? code;

  @override
  String toString() => message;
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Network request failed', super.code]);
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

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure([super.message = 'Unexpected error', super.code]);
}
