import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/cache/api_cache.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/features/routes/application/offline_routes_provider.dart';
import 'package:tourism_mobile/features/routes/data/api_routes_repository.dart';
import 'package:tourism_mobile/features/routes/data/caching_routes_repository.dart';
import 'package:tourism_mobile/features/routes/data/mock_routes_repository.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/domain/routes_repository.dart';

final routesRepositoryProvider = Provider<RoutesRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return MockRoutesRepository();
  }
  return CachingRoutesRepository(
    ApiRoutesRepository(ref.watch(dioProvider)),
    registry: ref.watch(apiCacheRegistryProvider),
  );
});

final routesListProvider = FutureProvider<RouteListPage>((ref) {
  return ref.watch(routesRepositoryProvider).listRoutes(regionSlug: 'crimea');
});

/// Public, moderation-approved routes ordered by favorites and then freshness.
/// Kept separate from the swipe catalog so the home feed can warm independently.
final homeRoutesProvider = FutureProvider<RouteListPage>((ref) {
  return ref
      .watch(routesRepositoryProvider)
      .listRoutes(
        regionSlug: 'crimea',
        limit: 100,
        sort: RouteCatalogSort.popular,
      );
});

final routeDetailProvider = FutureProvider.autoDispose
    .family<RouteDetail, String>(_getRouteWithOfflineFallback);

final routesForPlaceProvider = FutureProvider.autoDispose
    .family<RouteListPage, String>((ref, placeId) {
      return ref
          .watch(routesRepositoryProvider)
          .listRoutes(placeId: placeId, limit: 10);
    });

/// Free-text route search, mirroring `placesSearchProvider` — used by pickers
/// that need to find one route by name.
final routesSearchProvider = FutureProvider.autoDispose
    .family<RouteListPage, String>((ref, query) {
      return ref
          .watch(routesRepositoryProvider)
          .listRoutes(regionSlug: 'crimea', query: query.trim(), limit: 20);
    });

final ownRouteDetailProvider = FutureProvider.autoDispose
    .family<RouteDetail, String>(_getOwnRouteWithOfflineFallback);

Future<RouteDetail> _getRouteWithOfflineFallback(Ref ref, String id) async {
  try {
    return await ref.watch(routesRepositoryProvider).getRoute(id);
  } on Object {
    final cached = await ref.read(offlineRouteStoreProvider).get(id);
    if (cached != null) {
      return cached.route;
    }
    rethrow;
  }
}

Future<RouteDetail> _getOwnRouteWithOfflineFallback(Ref ref, String id) async {
  try {
    return await ref.watch(routesRepositoryProvider).getMyRoute(id);
  } on Object {
    final cached = await ref.read(offlineRouteStoreProvider).get(id);
    if (cached != null) {
      return cached.route;
    }
    rethrow;
  }
}
