import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/storage/memory_secure_storage.dart';
import 'package:tourism_mobile/core/storage/secure_storage_provider.dart';
import 'package:tourism_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/settings/application/preferences_providers.dart';
import 'package:tourism_mobile/features/settings/data/preferences_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/personalization_prompt.dart';

final class _IncompletePreferencesRepository implements PreferencesRepository {
  @override
  Future<TravelPreferences> getPreferences() async => const TravelPreferences();

  @override
  Future<TravelPreferences> updatePreferences({
    required List<String> categories,
    required String? difficulty,
    required bool travelsWithKids,
    required bool travelsWithPets,
  }) async => TravelPreferences(
    categories: categories,
    difficulty: difficulty,
    travelsWithKids: travelsWithKids,
    travelsWithPets: travelsWithPets,
    updatedAt: DateTime.now(),
  );
}

void main() {
  testWidgets('invites an API user to personalize and can be dismissed', (
    tester,
  ) async {
    final storage = MemorySecureStorage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(
              AppEnvironment.test,
              apiBaseUrl: 'https://api.test.local',
              dataSource: AppDataSource.api,
            ),
          ),
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
          secureStorageProvider.overrideWithValue(storage),
          sessionProvider.overrideWith(
            (ref) => SessionController(
              authRepository: MockAuthRepository(),
              secureStorage: storage,
              useMockData: false,
              initial: const SessionState(
                isHydrated: true,
                onboardingCompleted: true,
                userId: 'user-1',
                accessToken: 'access-1',
              ),
            ),
          ),
          preferencesRepositoryProvider.overrideWithValue(
            _IncompletePreferencesRepository(),
          ),
        ],
        child: const MaterialApp(
          home: PersonalizationPromptHost(child: Scaffold(body: Text('Домой'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Соберём маршруты под вас'), findsOneWidget);
    expect(find.text('Настроить предпочтения'), findsOneWidget);

    await tester.tap(find.text('Позже'));
    await tester.pumpAndSettle();
    expect(find.text('Соберём маршруты под вас'), findsNothing);
    expect(find.text('Домой'), findsOneWidget);
  });
}
