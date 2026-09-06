import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/storage/memory_secure_storage.dart';
import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:tourism_mobile/features/auth/domain/auth_repository.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/onboarding/data/session_identity_cache.dart';

class _CountingAuth implements AuthRepository {
  var requestOtpCalls = 0;

  @override
  Future<OtpStartResult> requestOtp({
    required String phone,
    String? displayName,
  }) async {
    requestOtpCalls += 1;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return const OtpStartResult(
      registrationRequired: false,
      consentsRequired: false,
      otpSent: true,
    );
  }

  @override
  Future<AuthTokens> verifyOtp({
    required String phone,
    required String code,
    required bool privacyAccepted,
    required bool personalDataAccepted,
  }) => throw UnimplementedError();

  @override
  Future<AuthTokens> refresh(String refreshToken) => throw UnimplementedError();

  @override
  Future<void> logout(String refreshToken) => throw UnimplementedError();

  @override
  Future<MeProfile> getMe(String accessToken) => throw UnimplementedError();

  @override
  Future<MeProfile> patchMe({
    required String accessToken,
    String? displayName,
    bool? notifyPushEnabled,
    bool? notifySmsEnabled,
    bool? notifyHapticsEnabled,
  }) => throw UnimplementedError();

  @override
  Future<void> requestPhoneChange({
    required String accessToken,
    required String phone,
  }) => throw UnimplementedError();

  @override
  Future<MeProfile> verifyPhoneChange({
    required String accessToken,
    required String phone,
    required String code,
    required bool privacyAccepted,
    required bool personalDataAccepted,
  }) => throw UnimplementedError();

  @override
  Future<MeProfile> uploadAvatar({
    required String accessToken,
    required String filePath,
  }) => throw UnimplementedError();

  @override
  Future<MeProfile> uploadCover({
    required String accessToken,
    required String filePath,
  }) => throw UnimplementedError();

  @override
  Future<MeProfile> activateTravelPlus({
    required String accessToken,
    required String plan,
  }) => throw UnimplementedError();

  @override
  Future<MeProfile> cancelTravelPlus({required String accessToken}) =>
      throw UnimplementedError();
}

/// Every call fails as if there were no connectivity at all.
class _NetworkFailingAuth implements AuthRepository {
  @override
  Future<OtpStartResult> requestOtp({
    required String phone,
    String? displayName,
  }) => throw const NetworkFailure();

  @override
  Future<AuthTokens> verifyOtp({
    required String phone,
    required String code,
    required bool privacyAccepted,
    required bool personalDataAccepted,
  }) => throw const NetworkFailure();

  @override
  Future<AuthTokens> refresh(String refreshToken) =>
      throw const NetworkFailure();

  @override
  Future<void> logout(String refreshToken) => throw const NetworkFailure();

  @override
  Future<MeProfile> getMe(String accessToken) => throw const NetworkFailure();

  @override
  Future<MeProfile> patchMe({
    required String accessToken,
    String? displayName,
    bool? notifyPushEnabled,
    bool? notifySmsEnabled,
    bool? notifyHapticsEnabled,
  }) => throw const NetworkFailure();

  @override
  Future<void> requestPhoneChange({
    required String accessToken,
    required String phone,
  }) => throw const NetworkFailure();

  @override
  Future<MeProfile> verifyPhoneChange({
    required String accessToken,
    required String phone,
    required String code,
    required bool privacyAccepted,
    required bool personalDataAccepted,
  }) => throw const NetworkFailure();

  @override
  Future<MeProfile> uploadAvatar({
    required String accessToken,
    required String filePath,
  }) => throw const NetworkFailure();

  @override
  Future<MeProfile> uploadCover({
    required String accessToken,
    required String filePath,
  }) => throw const NetworkFailure();

  @override
  Future<MeProfile> activateTravelPlus({
    required String accessToken,
    required String plan,
  }) => throw const NetworkFailure();

  @override
  Future<MeProfile> cancelTravelPlus({required String accessToken}) =>
      throw const NetworkFailure();
}

void main() {
  test('verifyOtp persists refresh token and session profile', () async {
    final storage = MemorySecureStorage();
    final controller = SessionController(
      authRepository: MockAuthRepository(),
      secureStorage: storage,
      useMockData: true,
      initial: const SessionState(
        isHydrated: true,
        displayName: 'Никита',
        phone: '+79001234567',
      ),
    );

    await controller.verifyOtp(
      code: '1234',
      privacyAccepted: true,
      personalDataAccepted: true,
    );

    expect(controller.state.onboardingCompleted, isTrue);
    expect(controller.state.displayName, 'Никита');
    expect(await storage.read(key: SecureStorageKeys.refreshToken), isNotNull);
    expect(
      await storage.read(key: SecureStorageKeys.refreshToken),
      isNot(contains('access')),
    );
  });

  test('hydrate restores session from refresh token', () async {
    final storage = MemorySecureStorage();
    await storage.write(
      key: SecureStorageKeys.refreshToken,
      value: 'mock-refresh',
    );
    final controller = SessionController(
      authRepository: MockAuthRepository(),
      secureStorage: storage,
      useMockData: true,
    );
    await controller.hydrate();
    expect(controller.state.onboardingCompleted, isTrue);
    expect(controller.state.accessToken, isNotNull);
  });

  test('requestOtp coalesces concurrent calls into one request', () async {
    final auth = _CountingAuth();
    final controller = SessionController(
      authRepository: auth,
      secureStorage: MemorySecureStorage(),
      useMockData: false,
      initial: const SessionState(
        isHydrated: true,
        displayName: 'Никита',
        phone: '+79001234567',
      ),
    );

    await Future.wait([controller.requestOtp(), controller.requestOtp()]);

    expect(auth.requestOtpCalls, 1);
  });

  test('requestOtp rejects missing phone without calling the API', () async {
    final auth = _CountingAuth();
    final controller = SessionController(
      authRepository: auth,
      secureStorage: MemorySecureStorage(),
      useMockData: false,
    );

    await expectLater(controller.requestOtp(), throwsA(isA<AuthFailure>()));
    expect(auth.requestOtpCalls, 0);
  });

  test('clearSession awaits local account-data cleanup', () async {
    var localDataCleared = false;
    final controller = SessionController(
      authRepository: MockAuthRepository(),
      secureStorage: MemorySecureStorage(),
      useMockData: true,
      initial: const SessionState(
        isHydrated: true,
        onboardingCompleted: true,
        userId: 'user-1',
        accessToken: 'access-1',
      ),
      onSessionCleared: () async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        localDataCleared = true;
      },
    );

    await controller.clearSession();

    expect(localDataCleared, isTrue);
    expect(controller.state.isAuthenticated, isFalse);
  });

  test(
    'hydrate under NetworkFailure restores the cached identity instead of '
    'logging out',
    () async {
      final storage = MemorySecureStorage();
      await storage.write(
        key: SecureStorageKeys.refreshToken,
        value: 'refresh-1',
      );
      final identityCache = MemorySessionIdentityCache();
      await identityCache.save(
        const CachedIdentity(
          userId: 'user-1',
          displayName: 'Никита',
          phone: '+79001234567',
        ),
      );
      final controller = SessionController(
        authRepository: _NetworkFailingAuth(),
        secureStorage: storage,
        identityCache: identityCache,
        useMockData: false,
      );

      await controller.hydrate();

      expect(controller.state.isHydrated, isTrue);
      expect(controller.state.onboardingCompleted, isTrue);
      expect(controller.state.isOffline, isTrue);
      expect(controller.state.userId, 'user-1');
      expect(controller.state.displayName, 'Никита');
      expect(controller.state.isAuthenticated, isTrue);
      // The refresh token must survive — this is the whole point of the fix.
      expect(
        await storage.read(key: SecureStorageKeys.refreshToken),
        'refresh-1',
      );
    },
  );

  test(
    'hydrate under NetworkFailure with no cached identity falls back to '
    'logged out (cannot claim a session it cannot describe)',
    () async {
      final storage = MemorySecureStorage();
      await storage.write(
        key: SecureStorageKeys.refreshToken,
        value: 'refresh-1',
      );
      final controller = SessionController(
        authRepository: _NetworkFailingAuth(),
        secureStorage: storage,
        useMockData: false,
      );

      await controller.hydrate();

      expect(controller.state.isHydrated, isTrue);
      expect(controller.state.isAuthenticated, isFalse);
      expect(
        await storage.read(key: SecureStorageKeys.refreshToken),
        isNull,
      );
    },
  );

  test(
    'a mid-session refresh under NetworkFailure keeps the session instead '
    'of clearing it',
    () async {
      final storage = MemorySecureStorage();
      await storage.write(
        key: SecureStorageKeys.refreshToken,
        value: 'refresh-1',
      );
      final controller = SessionController(
        authRepository: _NetworkFailingAuth(),
        secureStorage: storage,
        useMockData: false,
        initial: const SessionState(
          isHydrated: true,
          onboardingCompleted: true,
          userId: 'user-1',
          accessToken: 'access-1',
        ),
      );

      final result = await controller.refreshAccessToken();

      expect(result, isNull);
      expect(controller.state.isOffline, isTrue);
      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.accessToken, 'access-1');
      expect(
        await storage.read(key: SecureStorageKeys.refreshToken),
        'refresh-1',
      );
    },
  );
}
