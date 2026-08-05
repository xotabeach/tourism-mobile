import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

class UniversalSearchResults {
  const UniversalSearchResults({
    this.routes = const [],
    this.profiles = const [],
  });

  final List<RouteSummary> routes;
  final List<PublicUserProfile> profiles;

  bool get isEmpty => routes.isEmpty && profiles.isEmpty;
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

      if (config.useMockData) {
        final page = await routesFuture;
        final normalized = query.toLowerCase();
        const candidates = [
          PublicUserProfile(
            id: 'mock-user',
            displayName: 'Никита Можаров',
            avatarUrl: AppImages.travelerPortrait,
            coverUrl: AppImages.welcomeSunset,
            travelPoints: 12500,
          ),
          PublicUserProfile(
            id: 'mock-maria',
            displayName: 'Мария Крымская',
            avatarUrl: AppImages.travelerPortrait,
            travelPoints: 8480,
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
        );
      }

      final results = await Future.wait<Object>([
        routesFuture,
        ref.watch(publicProfileRepositoryProvider).search(query),
      ]);
      return UniversalSearchResults(
        routes: (results[0] as RouteListPage).items,
        profiles: results[1] as List<PublicUserProfile>,
      );
    });
