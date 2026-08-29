import 'dart:math';

final _random = Random.secure();

/// Idempotency key for a mutation that may be delivered more than once.
///
/// The API dedupes by this value, so a queued offline action can be retried
/// safely. It is a UUID v4 because the backend validates the format, and it
/// carries no device or account data.
String newClientEventId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
