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

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure([super.message = 'Unexpected error']);
}
