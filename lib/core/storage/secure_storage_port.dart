/// Port over platform secure storage (iOS Keychain / Android Keystore-backed).
///
/// Phase 5: adapter only. Phase 6: refresh tokens via this port.
/// Do not store tokens in SharedPreferences or plain files.
abstract interface class SecureStoragePort {
  Future<void> write({required String key, required String value});

  Future<String?> read({required String key});

  Future<void> delete({required String key});

  Future<void> clear();
}

/// Well-known keys. Values are never logged.
abstract final class SecureStorageKeys {
  static const refreshToken = 'auth.refresh_token';
  static const appHapticsEnabled = 'settings.app_haptics_enabled';
}
