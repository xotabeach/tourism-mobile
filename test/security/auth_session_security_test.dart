import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/storage/memory_secure_storage.dart';
import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';

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
}
