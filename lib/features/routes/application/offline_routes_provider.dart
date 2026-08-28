import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/routes/data/offline_route_store.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

final offlineRouteStoreProvider = Provider<OfflineRouteStore>((ref) {
  return SharedPreferencesOfflineRouteStore();
});

final offlineRoutesProvider = FutureProvider<List<OfflineRouteRecord>>((ref) {
  return ref.watch(offlineRouteStoreProvider).list();
});

final offlineRouteByIdProvider = FutureProvider.autoDispose
    .family<OfflineRouteRecord?, String>((ref, id) {
      return ref.watch(offlineRouteStoreProvider).get(id);
    });

/// Save a complete detail snapshot and refresh all consumers of the offline
/// list. The operation is intentionally explicit; favouriting alone must not
/// silently consume storage unless the user enabled that setting and the
/// follow-up auto-download workstream is active.
Future<void> downloadRouteSnapshot(WidgetRef ref, RouteDetail route) async {
  await ref.read(offlineRouteStoreProvider).save(route);
  ref.invalidate(offlineRoutesProvider);
  ref.invalidate(offlineRouteByIdProvider(route.id));

  // Warm media after the JSON commit. A failed image must not invalidate the
  // readable route snapshot, so each download remains best effort.
  final urls = _routeMediaUrls(ref.read(appConfigProvider), route);
  await Future.wait(
    urls.map(
      (url) => AppImages.cacheManager
          .downloadFile(url)
          .then<void>((_) {})
          .catchError((_) {}),
    ),
  );
}

Future<void> removeDownloadedRoute(WidgetRef ref, String routeId) async {
  final store = ref.read(offlineRouteStoreProvider);
  final removed = await store.get(routeId);
  await store.remove(routeId);
  if (removed != null) {
    final config = ref.read(appConfigProvider);
    final retainedUrls = <String>{
      for (final record in await store.list())
        ..._routeMediaUrls(config, record.route),
    };
    final removableUrls = _routeMediaUrls(
      config,
      removed.route,
    ).difference(retainedUrls);
    await Future.wait(removableUrls.map(AppImages.evictNetworkImage));
  }
  ref.invalidate(offlineRoutesProvider);
  ref.invalidate(offlineRouteByIdProvider(routeId));
}

Future<void> clearDownloadedRoutes(WidgetRef ref) async {
  await clearOfflineRouteData(ref.read(offlineRouteStoreProvider));
  ref.invalidate(offlineRoutesProvider);
}

/// Shared by the settings action and logout. Clearing the whole image cache is
/// deliberate: route snapshots may contain private media and a corrupt/old
/// snapshot cannot reliably tell us every cache key it previously referenced.
Future<void> clearOfflineRouteData(OfflineRouteStore store) async {
  await store.clear();
  await AppImages.clearNetworkImageCache();
}

Set<String> _routeMediaUrls(AppConfig config, RouteDetail route) {
  return <String?>{
        route.coverImageUrl,
        ...route.media.where((item) => item.isImage).map((item) => item.url),
      }
      .map((raw) => AppImages.resolveMediaUrl(config, raw))
      .whereType<String>()
      .toSet();
}
