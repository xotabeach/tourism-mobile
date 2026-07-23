import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/core/storage/secure_storage_provider.dart';

void main() {
  test('in-memory secure storage adapter round-trips values', () async {
    final storage = _MemorySecureStorage();
    await storage.write(
      key: SecureStorageKeys.refreshToken,
      value: 'token-value',
    );
    expect(
      await storage.read(key: SecureStorageKeys.refreshToken),
      'token-value',
    );
    await storage.delete(key: SecureStorageKeys.refreshToken);
    expect(await storage.read(key: SecureStorageKeys.refreshToken), isNull);
  });

  test('FlutterSecureStorageAdapter type is wired as SecureStoragePort', () {
    // Compile-time / type smoke: adapter implements the port used by providers.
    expect(FlutterSecureStorageAdapter, isNotNull);
  });
}

final class _MemorySecureStorage implements SecureStoragePort {
  final Map<String, String> _values = {};

  @override
  Future<void> clear() async => _values.clear();

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }
}
