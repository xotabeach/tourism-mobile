import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/cache/api_cache.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/places/data/api_places_repository.dart';
import 'package:tourism_mobile/features/places/data/caching_places_repository.dart';
import 'package:tourism_mobile/features/places/data/mock_places_repository.dart';
import 'package:tourism_mobile/features/places/data/place_view_reporter.dart';
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

/// Mirrors `homeRoutesProvider` — a small, independent fetch for the home
/// feed's Локации mode so it can warm separately from the places catalog tab.
/// Refresh scopes invalidate this the way they invalidate `homeRoutesProvider`.
final homePlacesProvider = FutureProvider<PlaceListPage>((ref) {
  return ref
      .watch(placesRepositoryProvider)
      .listPlaces(regionSlug: 'crimea', limit: 20);
});

final placesSearchProvider = FutureProvider.autoDispose
    .family<PlaceListPage, String>((ref, query) {
      return ref
          .watch(placesRepositoryProvider)
          .listPlaces(regionSlug: 'crimea', query: query.trim());
    });

/// Tells the server that a signed-in person opened a place card (spec 19).
final placeViewReporterProvider = Provider<PlaceViewReporter>((ref) {
  final config = ref.watch(appConfigProvider);
  return PlaceViewReporter(
    ref.watch(dioProvider),
    isEnabled: () =>
        !config.useMockData && ref.read(sessionProvider).isAuthenticated,
  );
});

final placeDetailProvider = FutureProvider.autoDispose
    .family<PlaceDetail, String>((ref, id) async {
      final place = await ref.watch(placesRepositoryProvider).getPlace(id);
      ref.read(placeViewReporterProvider).report(id);
      return place;
    });
