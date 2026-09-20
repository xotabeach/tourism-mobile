import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/features/route_execution/application/route_start_block.dart';

class _MemoryStorage implements SecureStoragePort {
  final values = <String, String>{};

  @override
  Future<void> write({required String key, required String value}) async =>
      values[key] = value;

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}

void main() {
  final now = DateTime.utc(2026, 9, 20, 12);

  test('describes the remaining time in minutes, hours or days', () {
    expect(
      describeBlockedUntil(now.add(const Duration(minutes: 40)), now),
      startsWith('через 40 мин ('),
    );
    expect(
      describeBlockedUntil(now.add(const Duration(hours: 5)), now),
      startsWith('через 5 ч ('),
    );
    expect(
      describeBlockedUntil(now.add(const Duration(days: 7)), now),
      startsWith('через 7 дн ('),
    );
    expect(
      describeBlockedUntil(now.add(const Duration(seconds: 20)), now),
      startsWith('совсем скоро'),
    );
  });

  test('the message stays calm and works without a deadline', () {
    final text = blockedStartMessage(null, now);
    expect(text, contains('временно недоступен'));
    expect(text, contains('очки проверит команда'));
  });

  test('the deadline is stored and cleared', () async {
    final storage = _MemoryStorage();
    final store = RouteStartBlockStore(storage);
    final until = now.add(const Duration(hours: 1));
    await store.write(until);
    expect(await store.read(), until);
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('a blocked start is its own failure type, not an auth failure', () {
    const failure = RouteStartBlockedFailure(null);
    expect(failure, isA<AppFailure>());
    expect(failure, isNot(isA<AuthFailure>()));
    expect(failure.code, 'route_start_blocked');
  });

  DioException forbidden(String code, Map<String, Object?> details) {
    final request = RequestOptions(path: '/x');
    return DioException(
      requestOptions: request,
      response: Response<Map<String, Object?>>(
        requestOptions: request,
        statusCode: 403,
        data: {
          'error': {'code': code, 'message': 'msg', 'details': details},
        },
      ),
    );
  }

  test(
    '403 route_start_blocked keeps the session and carries the deadline',
    () async {
      final error = forbidden('route_start_blocked', {
        'blocked_until': '2026-09-21T14:30:00+00:00',
      });
      await expectLater(
        guardApiCall<void>(() async => throw error),
        throwsA(
          isA<RouteStartBlockedFailure>().having(
            (f) => f.blockedUntil,
            'blockedUntil',
            DateTime.utc(2026, 9, 21, 14, 30),
          ),
        ),
      );
    },
  );

  test('any other 403 is still an auth failure', () async {
    await expectLater(
      guardApiCall<void>(() async => throw forbidden('forbidden', {})),
      throwsA(isA<AuthFailure>()),
    );
  });
}
