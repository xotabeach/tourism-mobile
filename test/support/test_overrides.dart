import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/storage/memory_secure_storage.dart';
import 'package:tourism_mobile/core/storage/secure_storage_provider.dart';
import 'package:tourism_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/search/application/search_history_provider.dart';

const testAppConfig = AppConfig(
  environment: AppEnvironment.local,
  apiBaseUrl: 'http://localhost:8000',
  appName: 'КрымТрип (Test)',
  dataSource: AppDataSource.mock,
);

List<Override> testSessionOverrides({
  bool onboardingCompleted = false,
  String displayName = 'Никита',
  bool travelPlusActive = false,
  String? travelPlusPlan,
  DateTime? travelPlusExpiresAt,
}) {
  final storage = MemorySecureStorage();
  return [
    appConfigProvider.overrideWithValue(testAppConfig),
    secureStorageProvider.overrideWithValue(storage),
    authRepositoryProvider.overrideWithValue(MockAuthRepository()),
    sessionProvider.overrideWith(
      (ref) => SessionController(
        authRepository: MockAuthRepository(),
        secureStorage: storage,
        useMockData: true,
        initial: SessionState(
          isHydrated: true,
          onboardingCompleted: onboardingCompleted,
          displayName: onboardingCompleted ? displayName : null,
          phone: onboardingCompleted ? '+79001234567' : null,
          userId: onboardingCompleted ? 'mock-user' : null,
          accessToken: onboardingCompleted ? 'mock-access' : null,
          travelPlusActive: travelPlusActive,
          travelPlusPlan: travelPlusPlan,
          travelPlusExpiresAt: travelPlusExpiresAt,
        ),
      ),
    ),
    searchHistoryStoreProvider.overrideWithValue(MemorySearchHistoryStore()),
  ];
}
