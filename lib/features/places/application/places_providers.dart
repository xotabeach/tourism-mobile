import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/cache/api_cache.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/features/places/data/api_places_repository.dart';
import 'package:tourism_mobile/features/places/data/caching_places_repository.dart';
import 'package:tourism_mobile/features/places/data/mock_places_repository.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/places/domain/places_repository.dart';

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return MockPlacesRepository();
  }
  return CachingPlacesRepository(
    ApiPlacesRepository(ref.watch(dioProvider)),
    registry: ref.watch(apiCacheRegistryProvider),
  );
});

final placesListProvider = FutureProvider<PlaceListPage>((ref) {
  return ref.watch(placesRepositoryProvider).listPlaces(regionSlug: 'crimea');
});

final placesSearchProvider = FutureProvider.autoDispose
    .family<PlaceListPage, String>((ref, query) {
      return ref
          .watch(placesRepositoryProvider)
          .listPlaces(regionSlug: 'crimea', query: query.trim());
    });

final placeDetailProvider = FutureProvider.autoDispose
    .family<PlaceDetail, String>((ref, id) {
      return ref.watch(placesRepositoryProvider).getPlace(id);
    });
