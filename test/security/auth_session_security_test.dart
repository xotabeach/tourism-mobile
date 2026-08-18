import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/storage/memory_secure_storage.dart';
import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:tourism_mobile/features/auth/domain/auth_repository.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';

class _CountingAuth implements AuthRepository {
  var requestOtpCalls = 0;

  @override
  Future<void> requestOtp({
    required String displayName,
    required String phone,
  }) async {
    requestOtpCalls += 1;
    await Future<void>.delayed(const Duration(milliseconds: 40));
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

    await Future.wait<void>([controller.requestOtp(), controller.requestOtp()]);

    expect(auth.requestOtpCalls, 1);
  });

  test('requestOtp rejects missing identity without calling the API', () async {
    final auth = _CountingAuth();
    final controller = SessionController(
      authRepository: auth,
      secureStorage: MemorySecureStorage(),
      useMockData: false,
    );

    await expectLater(controller.requestOtp(), throwsA(isA<AuthFailure>()));
    expect(auth.requestOtpCalls, 0);
  });
}
