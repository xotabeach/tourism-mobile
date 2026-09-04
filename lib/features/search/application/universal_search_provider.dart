import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
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
    this.articles = const [],
  });

  final List<RouteSummary> routes;
  final List<PublicUserProfile> profiles;
  final List<PlaceSummary> places;

  /// Blogs are content like everything else here — the search covered routes,
  /// places and people, and could not find an article (asked 2026-09-04).
  final List<ArticleSummary> articles;

  bool get isEmpty =>
      routes.isEmpty && profiles.isEmpty && places.isEmpty && articles.isEmpty;
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
      final articlesFuture = ref
          .watch(articlesRepositoryProvider)
          .listArticles(query: query, limit: 8);

      if (config.useMockData) {
        final results = await Future.wait<Object>([
          routesFuture,
          placesFuture,
          articlesFuture,
        ]);
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
            isExpert: true,
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
          articles: (results[2] as ArticleListPage).items,
        );
      }

      final results = await Future.wait<Object>([
        routesFuture,
        ref.watch(publicProfileRepositoryProvider).search(query),
        placesFuture,
        articlesFuture,
      ]);
      return UniversalSearchResults(
        routes: (results[0] as RouteListPage).items,
        profiles: results[1] as List<PublicUserProfile>,
        places: (results[2] as PlaceListPage).items.take(8).toList(),
        articles: (results[3] as ArticleListPage).items,
      );
    });
