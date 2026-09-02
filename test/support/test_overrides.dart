import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';
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
  String? avatarUrl,
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
          avatarUrl: onboardingCompleted ? avatarUrl : null,
          travelPlusActive: travelPlusActive,
          travelPlusPlan: travelPlusPlan,
          travelPlusExpiresAt: travelPlusExpiresAt,
        ),
      ),
    ),
    searchHistoryStoreProvider.overrideWithValue(MemorySearchHistoryStore()),
  ];
}

/// Pumps [TourismApp] and, when the session is already signed in, enters the
/// shell from the branded welcome screen (avatar / CTA → home).
Future<void> pumpTourismAppAtHome(
  WidgetTester tester, {
  List<Override> overrides = const [],
  bool onboardingCompleted = true,
  String? avatarUrl,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testSessionOverrides(
          onboardingCompleted: onboardingCompleted,
          avatarUrl: avatarUrl,
        ),
        ...overrides,
      ],
      child: const TourismApp(),
    ),
  );
  await tester.pumpAndSettle();
  if (!onboardingCompleted) {
    return;
  }
  final start = find.text('Начать путешествие');
  if (start.evaluate().isNotEmpty) {
    await tester.tap(start);
    await tester.pumpAndSettle();
  }
}

/// Opens the favorites screen's section dropdown and picks [label].
///
/// The screen used to show its sections as a grid of chips, so tests tapped
/// the label directly; with five sections they live behind a dropdown and
/// only the selected one is on screen while it is closed.
Future<void> selectMyRoutesSection(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('section-dropdown-header')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
