import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/search/application/search_history_provider.dart';
import 'package:tourism_mobile/features/search/application/universal_search_provider.dart';
import 'package:tourism_mobile/features/search/presentation/search_filters_sheet.dart';
import 'package:tourism_mobile/features/search/presentation/universal_search_panel.dart';
import 'package:tourism_mobile/routing/app_router.dart';

enum SearchScope { global, routes, places, profiles }

class _SearchResultsSkeleton extends StatelessWidget {
  const _SearchResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 0, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeleton(width: 146, height: 22, borderRadius: 8),
            SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  AppSkeleton(width: 276, height: 178, borderRadius: 18),
                  SizedBox(width: 12),
                  AppSkeleton(width: 44, height: 178, borderRadius: 18),
                ],
              ),
            ),
            SizedBox(height: 22),
            AppSkeleton(width: 112, height: 22, borderRadius: 8),
            SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  AppSkeleton(width: 276, height: 178, borderRadius: 18),
                  SizedBox(width: 12),
                  AppSkeleton(width: 44, height: 178, borderRadius: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InPlaceSearchBody extends ConsumerStatefulWidget {
  const InPlaceSearchBody({
    required this.query,
    this.scope = SearchScope.global,
    this.filters = const SearchFilters(),
    this.onQueryFromHistory,
    this.localRoutes,
    this.localPlaces,
    this.localProfiles,
    super.key,
  });

  final String query;
  final SearchScope scope;
  final SearchFilters filters;
  final ValueChanged<String>? onQueryFromHistory;
  final List<RouteSummary>? localRoutes;
  final List<PlaceSummary>? localPlaces;
  final List<PublicUserProfile>? localProfiles;

  @override
  ConsumerState<InPlaceSearchBody> createState() => _InPlaceSearchBodyState();
}

class _InPlaceSearchBodyState extends ConsumerState<InPlaceSearchBody> {
  SearchHistoryController? _history;

  @override
  void initState() {
    super.initState();
    _history = ref.read(searchHistoryProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _history?.beginSession();
    });
  }

  @override
  void dispose() {
    _history?.endSession(lastQuery: widget.query);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(searchHistoryProvider.notifier).visibleHistory;
    ref.watch(searchHistoryProvider);
    final trimmed = widget.query.trim();
    final searching = trimmed.runes.length >= 2;
    final useLocal =
        widget.localRoutes != null ||
        widget.localPlaces != null ||
        widget.localProfiles != null;
    final results = (!useLocal && searching)
        ? ref.watch(universalSearchProvider(trimmed))
        : const AsyncValue.data(UniversalSearchResults());

    return results.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => const _SearchResultsSkeleton(),
      error: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text('Не удалось выполнить поиск')),
      ),
      data: (raw) {
        final data = _applyFilters(
          raw,
          scope: widget.scope,
          filters: widget.filters,
        );
        final showPeople = useLocal
            ? widget.localProfiles != null
            : widget.scope == SearchScope.global ||
                  widget.scope == SearchScope.profiles;
        final showRoutes = useLocal
            ? widget.localRoutes != null
            : widget.scope == SearchScope.global ||
                  widget.scope == SearchScope.routes;
        final showPlaces = useLocal
            ? widget.localPlaces != null
            : widget.scope == SearchScope.global ||
                  widget.scope == SearchScope.places;

        late final List<PublicUserProfile> people;
        late final List<RouteSummary> routes;
        late final List<PlaceSummary> places;
        if (useLocal) {
          people = _filterLocalProfiles(
            widget.localProfiles ?? const [],
            trimmed,
          );
          routes = _filterLocalRoutes(widget.localRoutes ?? const [], trimmed);
          places = _filterLocalPlaces(widget.localPlaces ?? const [], trimmed);
        } else {
          final discoveryPeople = ref.watch(topTravelersProvider);
          final discoveryRoutes = ref.watch(homeRoutesProvider);
          final discoveryPlaces = ref.watch(placesListProvider);
          people = searching
              ? data.profiles
              : (showPeople
                    ? discoveryPeople.valueOrNull ?? const <PublicUserProfile>[]
                    : const <PublicUserProfile>[]);
          routes = searching
              ? data.routes
              : (showRoutes
                    ? (discoveryRoutes.valueOrNull?.items ??
                              const <RouteSummary>[])
                          .take(5)
                          .toList()
                    : const <RouteSummary>[]);
          places = searching
              ? data.places
              : (showPlaces
                    ? (discoveryPlaces.valueOrNull?.items ??
                              const <PlaceSummary>[])
                          .take(5)
                          .toList()
                    : const <PlaceSummary>[]);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (history.isNotEmpty) ...[
              const _SearchSectionTitle('История:'),
              const SizedBox(height: 8),
              for (var i = 0; i < history.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _HistoryTile(
                  label: history[i],
                  onTap: () => widget.onQueryFromHistory?.call(history[i]),
                ),
              ],
              const SizedBox(height: 16),
            ],
            if (showPeople && people.isNotEmpty)
              _SearchResultBlock(
                title: 'Люди:',
                child: _HorizontalCards<PublicUserProfile>(
                  items: people.take(5).toList(),
                  height: 88,
                  itemBuilder: (context, profile) => DiscoveryProfileCard(
                    profile: profile,
                    height: 88,
                    onTap: () => _openProfile(context, profile),
                  ),
                ),
              ),
            if (showRoutes && routes.isNotEmpty)
              _SearchResultBlock(
                title: 'Маршруты:',
                child: _HorizontalCards<RouteSummary>(
                  items: routes.take(5).toList(),
                  height: 220,
                  itemBuilder: (context, route) =>
                      RouteHeroCard(route: route, height: 220),
                ),
              ),
            if (showPlaces && places.isNotEmpty)
              _SearchResultBlock(
                title: 'Места:',
                onSeeAll: widget.scope == SearchScope.global
                    ? () => unawaited(context.pushNamed(AppRouteNames.places))
                    : null,
                seeAllSemanticLabel: 'Все места',
                child: _HorizontalCards<PlaceSummary>(
                  items: places.take(5).toList(),
                  height: 220,
                  itemBuilder: (context, place) => _PlaceHeroSearchCard(
                    place: place,
                    onTap: () {
                      unawaited(
                        context.pushNamed(
                          AppRouteNames.placeDetails,
                          pathParameters: {'id': place.id},
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (searching &&
                people.isEmpty &&
                routes.isEmpty &&
                places.isEmpty &&
                history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('Ничего не найдено')),
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  UniversalSearchResults _applyFilters(
    UniversalSearchResults data, {
    required SearchScope scope,
    required SearchFilters filters,
  }) {
    var profiles = data.profiles;
    var routes = data.routes;
    var places = data.places;
    if (scope == SearchScope.routes || filters.target == SearchTarget.routes) {
      profiles = const [];
      places = const [];
    } else if (scope == SearchScope.places ||
        filters.target == SearchTarget.places) {
      profiles = const [];
      routes = const [];
    } else if (scope == SearchScope.profiles ||
        filters.target == SearchTarget.profiles) {
      routes = const [];
      places = const [];
    }
    if (filters.tags.isNotEmpty) {
      routes = routes
          .where((route) {
            final haystack =
                '${route.name} ${route.shortDescription ?? ''} '
                        '${route.authorLabel ?? ''} ${route.difficulty ?? ''}'
                    .toLowerCase();
            return _matchesAnyTag(haystack, filters.tags);
          })
          .toList(growable: false);
      places = places
          .where((place) {
            final haystack =
                '${place.name} ${place.shortDescription ?? ''} '
                        '${place.categories.map((c) => c.name).join(' ')} '
                        '${place.difficulty ?? ''}'
                    .toLowerCase();
            return _matchesAnyTag(haystack, filters.tags);
          })
          .toList(growable: false);
    }
    return UniversalSearchResults(
      profiles: profiles,
      routes: routes,
      places: places,
    );
  }

  List<PublicUserProfile> _filterLocalProfiles(
    List<PublicUserProfile> items,
    String query,
  ) {
    if (query.runes.length < 2) {
      return items.take(5).toList(growable: false);
    }
    final needle = query.toLowerCase();
    return items
        .where((profile) => profile.displayName.toLowerCase().contains(needle))
        .toList(growable: false);
  }

  List<RouteSummary> _filterLocalRoutes(
    List<RouteSummary> items,
    String query,
  ) {
    if (query.runes.length < 2) {
      return items.take(5).toList(growable: false);
    }
    final needle = query.toLowerCase();
    return items
        .where((route) {
          final haystack =
              '${route.name} ${route.shortDescription ?? ''} ${route.authorLabel ?? ''}'
                  .toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);
  }

  List<PlaceSummary> _filterLocalPlaces(
    List<PlaceSummary> items,
    String query,
  ) {
    if (query.runes.length < 2) {
      return items.take(5).toList(growable: false);
    }
    final needle = query.toLowerCase();
    return items
        .where((place) {
          final categories = place.categories
              .map((category) => category.name)
              .join(' ');
          final haystack =
              '${place.name} ${place.shortDescription ?? ''} $categories'
                  .toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);
  }

  bool _matchesAnyTag(String haystack, Set<String> tags) {
    for (final tag in tags) {
      final needle = switch (tag) {
        'С детьми' => 'дет',
        'Сложные' => 'hard',
        'Отдых' => 'легк',
        _ => tag.toLowerCase(),
      };
      if (haystack.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  void _openProfile(BuildContext context, PublicUserProfile profile) {
    unawaited(
      context.pushNamed(
        AppRouteNames.userProfile,
        pathParameters: {'userId': profile.id},
      ),
    );
  }
}

class _SearchSectionTitle extends StatelessWidget {
  const _SearchSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.sectionTitle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SearchResultBlock extends StatelessWidget {
  const _SearchResultBlock({
    required this.title,
    required this.child,
    this.onSeeAll,
    this.seeAllSemanticLabel,
  });

  final String title;
  final Widget child;
  final VoidCallback? onSeeAll;
  final String? seeAllSemanticLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _SearchSectionTitle(title)),
              if (onSeeAll != null)
                Semantics(
                  button: true,
                  label: seeAllSemanticLabel ?? 'Все',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSeeAll,
                    child: const Text(
                      'Все',
                      style: AppTypography.sectionAction,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: 8,
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.accentBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.search_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        title: Text(label, style: AppTypography.settingsRowTitle),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.secondaryInk,
        ),
      ),
    );
  }
}

class _HorizontalCards<T> extends StatefulWidget {
  const _HorizontalCards({
    required this.items,
    required this.height,
    required this.itemBuilder,
  });

  final List<T> items;
  final double height;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  State<_HorizontalCards<T>> createState() => _HorizontalCardsState<T>();
}

class _HorizontalCardsState<T> extends State<_HorizontalCards<T>> {
  late final _controller = PageController(viewportFraction: 0.92);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length.clamp(0, 5);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: widget.height + 20,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minWidth: viewportWidth,
        maxWidth: viewportWidth,
        child: Column(
          children: [
            SizedBox(
              key: const ValueKey('search-horizontal-viewport'),
              height: widget.height,
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.items.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(
                    right: index == widget.items.length - 1 ? 0 : 12,
                  ),
                  child: widget.itemBuilder(context, widget.items[index]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Container(
                    width: i == _index ? 10 : 8,
                    height: i == _index ? 10 : 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? AppColors.primaryInk
                          : AppColors.hairline,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceHeroSearchCard extends ConsumerWidget {
  const _PlaceHeroSearchCard({required this.place, required this.onTap});

  final PlaceSummary place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final category = place.categories.isEmpty
        ? 'Крым'
        : place.categories.first.name;
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImages.coverImage(
                config: config,
                coverImageUrl: place.coverImageUrl,
                fallbackSeed: place.slug,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x14000000), Color(0x99000000)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.place_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.favorite_border_rounded,
                          color: Colors.white,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.chip.copyWith(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category,
                      style: AppTypography.routeMetadata.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
