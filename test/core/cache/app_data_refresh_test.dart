import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/cache/api_cache.dart';
import 'package:tourism_mobile/core/cache/app_data_refresh.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

import '../../support/test_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('appDataRefreshScopeForTab', () {
    test('maps shell tabs to scopes', () {
      expect(appDataRefreshScopeForTab(0), AppDataRefreshScope.home);
      expect(appDataRefreshScopeForTab(1), AppDataRefreshScope.routesCatalog);
      expect(appDataRefreshScopeForTab(3), AppDataRefreshScope.myRoutes);
      expect(appDataRefreshScopeForTab(4), AppDataRefreshScope.profile);
      expect(appDataRefreshScopeForTab(2), AppDataRefreshScope.all);
    });
  });

  group('refreshAppDataInContainer', () {
    test('clears registered API caches', () async {
      final container = ProviderContainer(
        overrides: testSessionOverrides(onboardingCompleted: true),
      );
      addTearDown(container.dispose);

      final registry = container.read(apiCacheRegistryProvider);
      final cache = ApiCache<String, int>();
      registry.register(cache);
      cache.set('stale', 1);

      await refreshAppDataInContainer(
        container,
        scope: AppDataRefreshScope.home,
      );

      expect(cache.get('stale'), isNull);
    });

    test('profile scope reloads own routes after invalidate', () async {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          publicProfileProvider.overrideWith((ref, userId) async {
            calls += 1;
            final status = calls == 1 ? 'pending_review' : 'published';
            final base = ref.watch(profileProvider);
            return ProfileSnapshot(
              displayName: base.displayName,
              rank: base.rank,
              coverImageAsset: base.coverImageAsset,
              avatarImageAsset: base.avatarImageAsset,
              avatarImageUrl: base.avatarImageUrl,
              coverImageUrl: base.coverImageUrl,
              achievementPages: base.achievementPages,
              publishedRoutes: [
                RouteSummary(
                  id: 'route-1',
                  name: 'Тестовый маршрут',
                  slug: 'test-route',
                  shortDescription: 'desc',
                  stopsCount: 1,
                  ownerUserId: userId,
                  publicationStatus: status,
                  source: 'user_created',
                ),
              ],
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final first = await container.read(
        publicProfileProvider('mock-user').future,
      );
      expect(first.publishedRoutes.single.publicationStatus, 'pending_review');

      await refreshAppDataInContainer(
        container,
        scope: AppDataRefreshScope.profile,
        profileUserId: 'mock-user',
      );

      final second = await container.read(
        publicProfileProvider('mock-user').future,
      );
      expect(second.publishedRoutes.single.publicationStatus, 'published');
      expect(calls, greaterThanOrEqualTo(2));
    });

    test('home scope refreshes home routes future', () async {
      final container = ProviderContainer(
        overrides: testSessionOverrides(onboardingCompleted: true),
      );
      addTearDown(container.dispose);

      final before = await container.read(homeRoutesProvider.future);
      expect(before.items, isNotEmpty);

      await refreshAppDataInContainer(
        container,
        scope: AppDataRefreshScope.home,
      );

      final after = await container.read(homeRoutesProvider.future);
      expect(after.items, isNotEmpty);
    });
  });
}
