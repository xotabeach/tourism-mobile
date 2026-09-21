import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/storage/memory_secure_storage.dart';
import 'package:tourism_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/data/offline_own_routes_cache.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/data/mock_routes_repository.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

class _Session extends SessionController {
  _Session()
    : super(
        authRepository: MockAuthRepository(),
        secureStorage: MemorySecureStorage(),
        useMockData: false,
        initial: const SessionState(
          isHydrated: true,
          onboardingCompleted: true,
          userId: 'me',
          accessToken: 'token-1',
          displayName: 'Никита',
        ),
      );

  void replace(SessionState value) => state = value;
}

class _Profiles implements PublicProfileRepository {
  var fetches = 0;

  @override
  Future<PublicProfileBundle> fetch(String userId) async {
    fetches++;
    return PublicProfileBundle(
      user: PublicUserProfile(id: userId, displayName: 'Никита'),
      routes: const [],
    );
  }

  @override
  Future<List<ProfileAchievement>> achievements(String userId) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cache implements OfflineOwnRoutesCache {
  @override
  Future<void> clear() async {}

  @override
  Future<List<RouteSummary>?> read() async => null;

  @override
  Future<void> save(List<RouteSummary> routes) async {}
}

void main() {
  test(
    'a token refresh or an «offline» flip does not reload the profile',
    () async {
      final session = _Session();
      final profiles = _Profiles();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.local,
              apiBaseUrl: 'http://localhost:8000',
              appName: 'test',
              dataSource: AppDataSource.api,
            ),
          ),
          sessionProvider.overrideWith((ref) => session),
          publicProfileRepositoryProvider.overrideWithValue(profiles),
          routesRepositoryProvider.overrideWithValue(MockRoutesRepository()),
          offlineOwnRoutesCacheProvider.overrideWithValue(_Cache()),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(publicProfileProvider('me'), (_, _) {});
      addTearDown(sub.close);

      await container.read(publicProfileProvider('me').future);
      expect(profiles.fetches, 1);

      session
        ..replace(session.state.copyWith(accessToken: 'token-2'))
        ..replace(session.state.copyWith(isOffline: true))
        ..replace(session.state.copyWith(isOffline: false));
      await container.read(publicProfileProvider('me').future);

      expect(profiles.fetches, 1, reason: 'nothing the profile shows changed');
    },
  );
}
