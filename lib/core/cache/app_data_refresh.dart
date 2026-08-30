import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/cache/api_cache.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/routes/application/route_reviews_providers.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';

/// Which catalog / screen data to reload after clearing the in-memory API cache.
enum AppDataRefreshScope { home, routesCatalog, myRoutes, profile, places, all }

/// Maps bottom-nav branch indexes to a refresh scope.
AppDataRefreshScope appDataRefreshScopeForTab(int tabIndex) {
  return switch (tabIndex) {
    0 => AppDataRefreshScope.home,
    1 => AppDataRefreshScope.routesCatalog,
    3 => AppDataRefreshScope.myRoutes,
    4 => AppDataRefreshScope.profile,
    _ => AppDataRefreshScope.all,
  };
}

/// Clears TTL caches and invalidates Riverpod providers for [scope].
///
/// When [awaitPrimary] is true, waits for the primary network reload(s) so
/// [RefreshIndicator] can dismiss after data arrives.
Future<void> refreshAppData(
  WidgetRef ref, {
  AppDataRefreshScope scope = AppDataRefreshScope.all,
  bool awaitPrimary = true,
  String? profileUserId,
}) {
  return refreshAppDataInContainer(
    ProviderScope.containerOf(ref.context, listen: false),
    scope: scope,
    awaitPrimary: awaitPrimary,
    profileUserId: profileUserId,
  );
}

/// Same as [refreshAppData] for unit tests and non-widget callers.
Future<void> refreshAppDataInContainer(
  ProviderContainer container, {
  AppDataRefreshScope scope = AppDataRefreshScope.all,
  bool awaitPrimary = true,
  String? profileUserId,
}) async {
  container.read(apiCacheRegistryProvider).invalidateAll();
  _invalidateScope(container, scope, profileUserId: profileUserId);

  if (!awaitPrimary) {
    return;
  }

  final pending = <Future<void>>[
    _awaitPrimary(container, scope, profileUserId: profileUserId),
  ];
  if (scope == AppDataRefreshScope.myRoutes ||
      scope == AppDataRefreshScope.all) {
    pending.add(_refreshFavorites(container));
  }
  if (scope == AppDataRefreshScope.all) {
    pending.add(_refreshNotifications(container));
  }
  await Future.wait(pending);
}

/// Soft reload: drop caches and mark providers stale without awaiting network.
void softRefreshAppData(
  WidgetRef ref, {
  AppDataRefreshScope scope = AppDataRefreshScope.all,
  String? profileUserId,
}) {
  softRefreshAppDataInContainer(
    ProviderScope.containerOf(ref.context, listen: false),
    scope: scope,
    profileUserId: profileUserId,
  );
}

void softRefreshAppDataInContainer(
  ProviderContainer container, {
  AppDataRefreshScope scope = AppDataRefreshScope.all,
  String? profileUserId,
}) {
  unawaited(
    refreshAppDataInContainer(
      container,
      scope: scope,
      awaitPrimary: false,
      profileUserId: profileUserId,
    ),
  );
}

void _invalidateScope(
  ProviderContainer container,
  AppDataRefreshScope scope, {
  String? profileUserId,
}) {
  final session = container.read(sessionProvider);
  final userId = profileUserId ?? session.userId;

  void invalidateProfile() {
    if (userId != null && userId.isNotEmpty) {
      container.invalidate(publicProfileProvider(userId));
      // Achievements are shown on the same screen, so a pull-to-refresh that
      // left them stale looked like the refresh had done nothing.
      container.invalidate(userAchievementsProvider(userId));
    }
  }

  switch (scope) {
    case AppDataRefreshScope.home:
      container.invalidate(homeRoutesProvider);
      container.invalidate(homePlacesProvider);
      container.invalidate(topTravelersProvider);
    case AppDataRefreshScope.routesCatalog:
      container.invalidate(routesListProvider);
    case AppDataRefreshScope.myRoutes:
      container.invalidate(routesListProvider);
      container.invalidate(placesListProvider);
      container.invalidate(profileSubscriptionsProvider);
    case AppDataRefreshScope.profile:
      invalidateProfile();
      container.invalidate(myRouteReviewsProvider);
      container.invalidate(topTravelersProvider);
      container.invalidate(profileSubscriptionsProvider);
    case AppDataRefreshScope.places:
      container.invalidate(placesListProvider);
    case AppDataRefreshScope.all:
      container.invalidate(homeRoutesProvider);
      container.invalidate(homePlacesProvider);
      container.invalidate(routesListProvider);
      container.invalidate(placesListProvider);
      container.invalidate(topTravelersProvider);
      container.invalidate(travelersLeaderboardProvider);
      container.invalidate(profileSubscriptionsProvider);
      container.invalidate(myRouteReviewsProvider);
      invalidateProfile();
      container.invalidate(notificationsInboxProvider);
  }
}

Future<void> _awaitPrimary(
  ProviderContainer container,
  AppDataRefreshScope scope, {
  String? profileUserId,
}) async {
  final session = container.read(sessionProvider);
  final userId = profileUserId ?? session.userId;

  switch (scope) {
    case AppDataRefreshScope.home:
      await Future.wait([
        container.refresh(homeRoutesProvider.future),
        container.refresh(homePlacesProvider.future),
      ]);
    case AppDataRefreshScope.routesCatalog:
      await container.refresh(routesListProvider.future);
    case AppDataRefreshScope.myRoutes:
      await Future.wait([
        container.refresh(routesListProvider.future),
        container.refresh(placesListProvider.future),
        container.refresh(profileSubscriptionsProvider.future),
      ]);
    case AppDataRefreshScope.profile:
      if (userId != null && userId.isNotEmpty) {
        await container.refresh(publicProfileProvider(userId).future);
      }
    case AppDataRefreshScope.places:
      await container.refresh(placesListProvider.future);
    case AppDataRefreshScope.all:
      final jobs = <Future<Object?>>[
        container.refresh(homeRoutesProvider.future),
        container.refresh(homePlacesProvider.future),
        container.refresh(routesListProvider.future),
        container.refresh(placesListProvider.future),
      ];
      if (userId != null && userId.isNotEmpty) {
        jobs.add(container.refresh(publicProfileProvider(userId).future));
      }
      await Future.wait(jobs);
  }
}

Future<void> _refreshFavorites(ProviderContainer container) async {
  try {
    await container.read(favoritesProvider.notifier).refresh();
  } on Object {
    // Keep previous favorites; lists already refreshed.
  }
}

Future<void> _refreshNotifications(ProviderContainer container) async {
  try {
    await container.read(notificationsInboxProvider.notifier).refresh();
  } on Object {
    // Inbox is secondary to catalog refresh.
  }
}
