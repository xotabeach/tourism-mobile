import 'package:tourism_mobile/core/storage/secure_storage_port.dart';

/// In-memory secure storage for tests and local harnesses.
final class MemorySecureStorage implements SecureStoragePort {
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
