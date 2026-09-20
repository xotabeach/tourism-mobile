import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/storage/secure_storage_provider.dart';
import 'package:tourism_mobile/features/route_publish/application/route_draft_sync.dart';
import 'package:tourism_mobile/features/route_publish/data/api_route_publication_repository.dart';
import 'package:tourism_mobile/features/route_publish/data/route_draft_media_store.dart';
import 'package:tourism_mobile/features/route_publish/data/secure_route_draft_repository.dart';
import 'package:tourism_mobile/features/route_publish/domain/route_publish_repository.dart';

// Kept apart from the controller so session code can reach the draft storage
// (to clear it on sign-out) without depending on the editor itself.

final routeDraftMediaStoreProvider = Provider<RouteDraftMediaStore>((ref) {
  return AppDirRouteDraftMediaStore();
});

final routeDraftRepositoryProvider = Provider<RouteDraftRepository>((ref) {
  return SecureRouteDraftRepository(ref.watch(secureStorageProvider));
});

final routePublicationRepositoryProvider = Provider<RoutePublicationRepository>(
  (ref) {
    if (ref.watch(appConfigProvider).useMockData) {
      return const InMemoryRoutePublicationRepository();
    }
    return ApiRoutePublicationRepository(ref.watch(dioProvider));
  },
);

/// Sends drafts to the server for the whole session, outside any screen.
///
/// The explicit variable type breaks an inference cycle through the session
/// provider (session -> this -> publication repository -> dio -> session).
// ignore: omit_obvious_property_types
final Provider<RouteDraftSyncService> routeDraftSyncServiceProvider =
    Provider<RouteDraftSyncService>((ref) {
      final service = RouteDraftSyncService(
        drafts: ref.watch(routeDraftRepositoryProvider),
        publication: ref.watch(routePublicationRepositoryProvider),
        mediaStore: ref.watch(routeDraftMediaStoreProvider),
        storage: ref.watch(secureStorageProvider),
      );
      ref.onDispose(service.dispose);
      return service;
    });
