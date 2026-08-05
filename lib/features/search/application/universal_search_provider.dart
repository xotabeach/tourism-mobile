import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

class UniversalSearchResults {
  const UniversalSearchResults({
    this.routes = const [],
    this.profiles = const [],
    this.places = const [],
  });

  final List<RouteSummary> routes;
  final List<PublicUserProfile> profiles;
  final List<PlaceSummary> places;

  bool get isEmpty => routes.isEmpty && profiles.isEmpty && places.isEmpty;
}

final universalSearchProvider = FutureProvider.autoDispose
    .family<UniversalSearchResults, String>((ref, rawQuery) async {
      final query = rawQuery.trim();
      if (query.runes.length < 2) {
        return const UniversalSearchResults();
      }

      final config = ref.watch(appConfigProvider);
      final routesFuture = ref
          .watch(routesRepositoryProvider)
          .listRoutes(
            regionSlug: 'crimea',
            query: query,
            limit: 8,
            sort: RouteCatalogSort.popular,
          );
      final placesFuture = ref
          .watch(placesRepositoryProvider)
          .listPlaces(regionSlug: 'crimea', query: query);

      if (config.useMockData) {
        final results = await Future.wait([routesFuture, placesFuture]);
        final page = results[0] as RouteListPage;
        final normalized = query.toLowerCase();
        const candidates = [
          PublicUserProfile(
            id: 'mock-user',
            displayName: 'Никита Можаров',
            avatarUrl: AppImages.travelerPortrait,
            coverUrl: AppImages.welcomeSunset,
            travelPoints: 12500,
            rankSlug: 'advanced_hiker',
            rankTitle: 'Продвинутый пешеход',
            nextRankPoints: 25000,
            leaderboardPlace: 1,
          ),
          PublicUserProfile(
            id: 'mock-maria',
            displayName: 'Мария Крымская',
            avatarUrl: AppImages.travelerPortrait,
            travelPoints: 8480,
            rankSlug: 'explorer',
            rankTitle: 'Исследователь',
            nextRankPoints: 10000,
            leaderboardPlace: 2,
          ),
        ];
        return UniversalSearchResults(
          routes: page.items,
          profiles: candidates
              .where(
                (profile) =>
                    profile.displayName.toLowerCase().contains(normalized),
              )
              .toList(growable: false),
          places: (results[1] as PlaceListPage).items.take(8).toList(),
        );
      }

      final results = await Future.wait<Object>([
        routesFuture,
        ref.watch(publicProfileRepositoryProvider).search(query),
        placesFuture,
      ]);
      return UniversalSearchResults(
        routes: (results[0] as RouteListPage).items,
        profiles: results[1] as List<PublicUserProfile>,
        places: (results[2] as PlaceListPage).items.take(8).toList(),
      );
    });
