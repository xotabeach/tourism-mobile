import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/core/storage/secure_storage_provider.dart';

/// Remembers until when the server refuses to start new routes for this
/// account, so the message survives an app restart. Cleared on logout; the
/// server stays the judge, so a stale value only ever costs one re-check.
class RouteStartBlockStore {
  const RouteStartBlockStore(this._storage);

  static const key = 'route_start.blocked_until';

  final SecureStoragePort _storage;

  Future<DateTime?> read() async {
    try {
      final raw = await _storage.read(key: key);
      return raw == null ? null : DateTime.tryParse(raw);
    } on Object {
      return null;
    }
  }

  Future<void> write(DateTime until) async {
    try {
      await _storage.write(key: key, value: until.toUtc().toIso8601String());
    } on Object {
      // Not critical: the next start attempt asks the server again.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: key);
    } on Object {
      // Nothing to do.
    }
  }
}

final routeStartBlockStoreProvider = Provider<RouteStartBlockStore>(
  (ref) => RouteStartBlockStore(ref.watch(secureStorageProvider)),
);

/// Until when starting is refused, while that is still in the future.
/// Invalidate after the stored value changes.
final routeStartBlockedUntilProvider = FutureProvider.autoDispose<DateTime?>((
  ref,
) async {
  final until = await ref.watch(routeStartBlockStoreProvider).read();
  return until != null && until.isAfter(DateTime.now()) ? until : null;
});

/// "через 40 мин (14:30)" in the device's time zone.
String describeBlockedUntil(DateTime until, DateTime now) {
  final local = until.toLocal();
  final clock =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  final remaining = until.difference(now);
  if (remaining.inMinutes < 1) return 'совсем скоро ($clock)';
  final minutes = remaining.inMinutes;
  final span = minutes < 60
      ? '$minutes мин'
      : minutes < 60 * 48
      ? '${(minutes / 60).ceil()} ч'
      : '${(minutes / 60 / 24).ceil()} дн';
  return 'через $span ($clock)';
}

String blockedStartMessage(DateTime? until, DateTime now) {
  final when = until == null ? '' : ': ${describeBlockedUntil(until, now)}';
  return 'Запуск маршрутов временно недоступен$when. '
      'Мы заметили необычно быстрое прохождение, очки проверит команда.';
}
