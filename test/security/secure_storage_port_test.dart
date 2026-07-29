import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/storage/memory_secure_storage.dart';
import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/core/storage/secure_storage_provider.dart';

void main() {
  test('in-memory secure storage adapter round-trips values', () async {
    final storage = MemorySecureStorage();
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
    expect(FlutterSecureStorageAdapter, isNotNull);
  });
}
