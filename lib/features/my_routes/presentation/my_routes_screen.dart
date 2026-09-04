import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/cache/app_data_refresh.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/article_card.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/my_routes/presentation/widgets/section_dropdown.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_providers.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/search/application/search_filter_apply.dart';
import 'package:tourism_mobile/features/search/presentation/in_place_search.dart';
import 'package:tourism_mobile/features/search/presentation/search_filters_sheet.dart';
import 'package:tourism_mobile/features/search/presentation/universal_search_panel.dart';
import 'package:tourism_mobile/routing/app_router.dart';
import 'package:tourism_mobile/routing/shell/tab_scroll_to_top.dart';

enum MyRoutesTab { favorites, history, places, subscriptions, articles }

/// 4-й раздел nav bar: маршруты / места / статьи / подписки / история.
/// Разделы переключаются выпадающим списком — чипами их было бы уже пять.
class MyRoutesScreen extends ConsumerStatefulWidget {
  const MyRoutesScreen({super.key});

  static const routePath = '/my-routes';

  @override
  ConsumerState<MyRoutesScreen> createState() => _MyRoutesScreenState();
}

class _MyRoutesScreenState extends ConsumerState<MyRoutesScreen> {
  static const _branchIndex = 3;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'my-routes-search');
  Timer? _searchDebounce;
  MyRoutesTab _tab = MyRoutesTab.favorites;
  var _searchQuery = '';
  var _searchFocused = false;

  /// Фильтры хранятся отдельно для каждого раздела: выбранное для маршрутов
  /// не должно молча применяться к местам или подпискам — там и наборы
  /// фильтров разные.
  final _filtersByTab = <MyRoutesTab, SearchFilters>{};
  final _removedSubscriptionIds = <String>{};

  bool get _searchActive => _searchFocused || _searchQuery.isNotEmpty;

  SearchFilters get _filters => _filtersByTab[_tab] ?? const SearchFilters();

  /// Раздел уже выбран переключателем над списком, поэтому шторка не
  /// спрашивает «что ищем» и показывает только то, по чему этот раздел
  /// можно сортировать и фильтровать.
  static SearchFilterSections _sectionsFor(MyRoutesTab tab) => switch (tab) {
    MyRoutesTab.favorites => SearchFilterSections.routes,
    MyRoutesTab.places => SearchFilterSections.places,
    MyRoutesTab.articles => SearchFilterSections.articles,
    MyRoutesTab.subscriptions => SearchFilterSections.profiles,
    MyRoutesTab.history => SearchFilterSections.history,
  };

  Future<void> _openFilters() async {
    final tab = _tab;
    final applied = await showSearchFiltersSheet(
      context,
      initial: _filters,
      sections: _sectionsFor(tab),
    );
    if (applied == null || !mounted) {
      return;
    }
    setState(() => _filtersByTab[tab] = applied);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    syncTabScrolledDown(ref, 3, _scrollController.offset);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocus.addListener(() {
      if (mounted) {
        setState(() => _searchFocused = _searchFocus.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocus.dispose();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      final query = value.trim();
      setState(() => _searchQuery = query);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(tabScrollToTopProvider(_branchIndex), (previous, next) {
      if (!_scrollController.hasClients) {
        return;
      }
      unawaited(
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        ),
      );
    });

    final top = MediaQuery.paddingOf(context).top;
    final favorites = ref.watch(favoritesProvider);
    final routesAsync = ref.watch(routesListProvider);
    final subscriptionsAsync = ref.watch(profileSubscriptionsProvider);
    final visibleSubscriptionsAsync = subscriptionsAsync.whenData(
      (items) => items
          .where((item) => !_removedSubscriptionIds.contains(item.id))
          .toList(growable: false),
    );
    final placesAsync = ref.watch(placesListProvider);
    final historyAsync = ref.watch(routeExecutionHistoryProvider);
    final savedArticlesAsync = ref.watch(savedArticlesProvider);
    final savedArticles = savedArticlesAsync.valueOrNull?.items ?? const [];
    final routes = routesAsync.valueOrNull?.items ?? const <RouteSummary>[];
    final favoriteRoutes = routes
        .where((r) => favorites.routeIds.contains(r.id))
        .toList();
    final favoritePlaces =
        placesAsync.valueOrNull?.items
            .where((p) => favorites.placeIds.contains(p.id))
            .toList() ??
        const <PlaceSummary>[];
    final filtered = applyRouteFilters(switch (_tab) {
      MyRoutesTab.favorites => favoriteRoutes,
      MyRoutesTab.history => const <RouteSummary>[],
      MyRoutesTab.places => const <RouteSummary>[],
      MyRoutesTab.subscriptions => const <RouteSummary>[],
      MyRoutesTab.articles => const <RouteSummary>[],
    }, _filters);

    return ColoredBox(
      color: AppColors.pageSurface,
      child: RefreshIndicator(
        onRefresh: () =>
            refreshAppData(ref, scope: AppDataRefreshScope.myRoutes),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, top + 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Избранное',
                      style: AppTypography.sectionTitle.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppSearchFilterRow(
                      hintText: 'Маршрут или профиль',
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onSearchChanged: _onSearchChanged,
                      onSearchClear: () {
                        _searchDebounce?.cancel();
                        setState(() => _searchQuery = '');
                      },
                      onFilterTap: () => unawaited(_openFilters()),
                      filterApplied: _filters.isActive,
                    ),
                    const SizedBox(height: 14),
                    SectionDropdown<MyRoutesTab>(
                      selected: _tab,
                      onChanged: (tab) => setState(() => _tab = tab),
                      options: [
                        SectionOption(
                          value: MyRoutesTab.favorites,
                          label: 'Маршруты',
                          icon: Icons.route_rounded,
                          count: favoriteRoutes.length,
                        ),
                        SectionOption(
                          value: MyRoutesTab.places,
                          label: 'Места',
                          icon: Icons.place_rounded,
                          count: favoritePlaces.length,
                        ),
                        SectionOption(
                          value: MyRoutesTab.articles,
                          label: 'Статьи',
                          icon: Icons.article_rounded,
                          count: savedArticles.length,
                        ),
                        SectionOption(
                          value: MyRoutesTab.subscriptions,
                          label: 'Подписки',
                          icon: Icons.people_alt_rounded,
                          count: visibleSubscriptionsAsync.valueOrNull?.length,
                        ),
                        SectionOption(
                          value: MyRoutesTab.history,
                          label: 'История',
                          icon: Icons.history_rounded,
                          count: historyAsync.valueOrNull?.length,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (_searchActive)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                sliver: SliverToBoxAdapter(
                  child: InPlaceSearchBody(
                    query: _searchQuery,
                    filters: _filters,
                    scope: switch (_tab) {
                      MyRoutesTab.subscriptions => SearchScope.profiles,
                      MyRoutesTab.places => SearchScope.places,
                      MyRoutesTab.favorites ||
                      MyRoutesTab.history ||
                      MyRoutesTab.articles => SearchScope.routes,
                    },
                    localRoutes: switch (_tab) {
                      MyRoutesTab.favorites => favoriteRoutes,
                      MyRoutesTab.history => null,
                      MyRoutesTab.places ||
                      MyRoutesTab.subscriptions ||
                      MyRoutesTab.articles => null,
                    },
                    localPlaces: _tab == MyRoutesTab.places
                        ? favoritePlaces
                        : null,
                    localProfiles: _tab == MyRoutesTab.subscriptions
                        ? (visibleSubscriptionsAsync.valueOrNull ??
                              const <PublicUserProfile>[])
                        : null,
                    onQueryFromHistory: (value) {
                      _searchController.text = value;
                      _onSearchChanged(value);
                    },
                  ),
                ),
              )
            else if (_tab == MyRoutesTab.subscriptions)
              ..._subscriptionSlivers(
                visibleSubscriptionsAsync.whenData(
                  (items) => applyProfileFilters(items, _filters),
                ),
              )
            else if (_tab == MyRoutesTab.places)
              ..._placesSlivers(
                placesAsync,
                favoritePlaces: applyPlaceFilters(favoritePlaces, _filters),
              )
            else if (_tab == MyRoutesTab.history)
              ..._executionHistorySlivers(
                historyAsync.whenData(
                  (items) => applyExecutionFilters(items, _filters),
                ),
              )
            else if (_tab == MyRoutesTab.articles)
              ..._savedArticleSlivers(
                savedArticlesAsync.whenData(
                  (page) => ArticleListPage(
                    items: applyArticleFilters(page.items, _filters),
                    total: page.total,
                  ),
                ),
              )
            else
              ..._routeListSlivers(routesAsync, filtered: filtered),
          ],
        ),
      ),
    );
  }

  List<Widget> _routeListSlivers(
    AsyncValue<RouteListPage> routesAsync, {
    required List<RouteSummary> filtered,
  }) {
    return routesAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => const [_MyRoutesListSkeleton()],
      error: (_, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppAsyncErrorView(
            onRetry: () => unawaited(
              refreshAppData(ref, scope: AppDataRefreshScope.myRoutes),
            ),
          ),
        ),
      ],
      data: (_) {
        if (filtered.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Пока пусто',
                  style: AppTypography.settingsRowSubtitle,
                ),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final route = filtered[index];
                if (_tab == MyRoutesTab.favorites) {
                  return _FavoriteRouteTile(
                    key: ValueKey('favorite-route-${route.id}'),
                    route: route,
                    onRemove: () => _removeFavorite(route),
                  );
                }
                return RouteHeroCard(route: route, height: 295);
              },
            ),
          ),
        ];
      },
    );
  }

  List<Widget> _executionHistorySlivers(
    AsyncValue<List<RouteExecution>> history,
  ) {
    return history.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => const [_MyRoutesListSkeleton()],
      error: (_, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppAsyncErrorView(
            message: 'Не удалось загрузить историю прохождений',
            onRetry: () => ref.invalidate(routeExecutionHistoryProvider),
          ),
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Здесь появятся пройденные маршруты',
                  style: AppTypography.settingsRowSubtitle,
                ),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _ExecutionHistoryTile(execution: items[index]),
            ),
          ),
        ];
      },
    );
  }

  List<Widget> _subscriptionSlivers(
    AsyncValue<List<PublicUserProfile>> subscriptions,
  ) {
    return subscriptions.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => const [_MyRoutesListSkeleton()],
      error: (_, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppAsyncErrorView(
            message: 'Не удалось загрузить подписки',
            onRetry: () => unawaited(
              refreshAppData(ref, scope: AppDataRefreshScope.myRoutes),
            ),
          ),
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Пока пусто',
                  style: AppTypography.settingsRowSubtitle,
                ),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return _FavoriteSwipeTile(
                  key: ValueKey('favorite-profile-${item.id}'),
                  itemId: 'profile-${item.id}',
                  semanticLabel: '${item.displayName}, профиль в подписках',
                  onRemove: () => _removeSubscription(item),
                  childBuilder: (_) => DiscoveryProfileCard(
                    profile: item,
                    height: 88,
                    onTap: () {
                      if (item.id == 'mock-user') {
                        context.goNamed(AppRouteNames.profile);
                        return;
                      }
                      unawaited(
                        context.pushNamed(
                          AppRouteNames.userProfile,
                          pathParameters: {'userId': item.id},
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ];
      },
    );
  }

  List<Widget> _savedArticleSlivers(AsyncValue<ArticleListPage> savedAsync) {
    return savedAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      // Силуэт карточки статьи, а не маршрута: у статьи фото занимает
      // меньшую долю плитки, и скелетон маршрута дёргал вёрстку при подмене.
      loading: () => const [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 140),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                ArticleCardSkeleton(),
                SizedBox(height: 12),
                ArticleCardSkeleton(),
              ],
            ),
          ),
        ),
      ],
      error: (_, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppAsyncErrorView(
            message: 'Не удалось загрузить статьи',
            onRetry: () => ref.invalidate(savedArticlesProvider),
          ),
        ),
      ],
      data: (page) {
        if (page.items.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Здесь появятся статьи, которые вы сохранили',
                  textAlign: TextAlign.center,
                  style: AppTypography.settingsRowSubtitle,
                ),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
            sliver: SliverList.separated(
              itemCount: page.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final article = page.items[index];
                return _FavoriteSwipeTile(
                  key: ValueKey('saved-article-${article.id}'),
                  itemId: 'article-${article.id}',
                  semanticLabel: '${article.title}, сохранённая статья',
                  onRemove: () => _removeSavedArticle(article),
                  childBuilder: (_) => ArticleCard(article: article),
                );
              },
            ),
          ),
        ];
      },
    );
  }

  Future<void> _removeSavedArticle(ArticleSummary article) async {
    try {
      await ref
          .read(articlesRepositoryProvider)
          .setSaved(article.id, saved: false);
      ref.invalidate(savedArticlesProvider);
      if (!mounted) return;
      showAppNotice(
        context,
        '«${article.title}» убрана из сохранённых',
        actionLabel: 'Вернуть',
        onAction: () => unawaited(_restoreSavedArticle(article)),
      );
    } on Object {
      if (!mounted) return;
      showAppNotice(
        context,
        'Не удалось обновить сохранённые',
        kind: AppNoticeKind.error,
      );
    }
  }

  Future<void> _restoreSavedArticle(ArticleSummary article) async {
    try {
      await ref
          .read(articlesRepositoryProvider)
          .setSaved(article.id, saved: true);
      ref.invalidate(savedArticlesProvider);
    } on Object {
      if (!mounted) return;
      showAppNotice(
        context,
        'Не удалось вернуть статью',
        kind: AppNoticeKind.error,
      );
    }
  }

  List<Widget> _placesSlivers(
    AsyncValue<PlaceListPage> placesAsync, {
    required List<PlaceSummary> favoritePlaces,
  }) {
    return placesAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => const [_MyRoutesListSkeleton()],
      error: (_, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppAsyncErrorView(
            message: 'Не удалось загрузить места',
            onRetry: () => unawaited(
              refreshAppData(ref, scope: AppDataRefreshScope.myRoutes),
            ),
          ),
        ),
      ],
      data: (_) {
        if (favoritePlaces.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Пока пусто',
                  style: AppTypography.settingsRowSubtitle,
                ),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
            sliver: SliverList.separated(
              itemCount: favoritePlaces.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final place = favoritePlaces[index];
                return _FavoriteSwipeTile(
                  key: ValueKey('favorite-place-${place.id}'),
                  itemId: 'place-${place.id}',
                  semanticLabel: '${place.name}, место в избранном',
                  onRemove: () => _removeFavoritePlace(place),
                  childBuilder: (_) => DiscoveryPlaceCard(
                    place: place,
                    height: 88,
                    onTap: () => unawaited(
                      context.pushNamed(
                        AppRouteNames.placeDetails,
                        pathParameters: {'id': place.id},
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ];
      },
    );
  }

  Future<void> _removeFavorite(RouteSummary route) async {
    try {
      await ref.read(favoritesProvider.notifier).removeRoute(route.id);
      if (!mounted) return;
      showAppNotice(
        context,
        '«${route.name}» удалён из избранного',
        actionLabel: 'Вернуть',
        onAction: () => unawaited(_restoreFavorite(route.id)),
      );
    } on Object {
      if (!mounted) return;
      showAppNotice(
        context,
        'Не удалось обновить избранное',
        kind: AppNoticeKind.error,
      );
    }
  }

  Future<void> _restoreFavorite(String routeId) async {
    try {
      await ref.read(favoritesProvider.notifier).addRoute(routeId);
    } on Object {
      if (!mounted) return;
      showAppNotice(context, 'Не удалось вернуть маршрут');
    }
  }

  Future<void> _removeFavoritePlace(PlaceSummary place) async {
    try {
      await ref.read(favoritesProvider.notifier).removePlace(place.id);
      if (!mounted) return;
      showAppNotice(
        context,
        '«${place.name}» удалено из избранного',
        actionLabel: 'Вернуть',
        onAction: () =>
            unawaited(ref.read(favoritesProvider.notifier).addPlace(place.id)),
      );
    } on Object {
      if (!mounted) return;
      showAppNotice(
        context,
        'Не удалось обновить избранное',
        kind: AppNoticeKind.error,
      );
    }
  }

  Future<void> _removeSubscription(PublicUserProfile profile) async {
    setState(() => _removedSubscriptionIds.add(profile.id));
    try {
      if (!ref.read(appConfigProvider).useMockData) {
        await ref.read(publicProfileRepositoryProvider).unlike(profile.id);
        ref.invalidate(profileSubscriptionsProvider);
      }
      if (!mounted) return;
      showAppNotice(
        context,
        'Подписка на «${profile.displayName}» удалена',
        actionLabel: 'Вернуть',
        onAction: () => unawaited(_restoreSubscription(profile.id)),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _removedSubscriptionIds.remove(profile.id));
      showAppNotice(
        context,
        'Не удалось удалить подписку',
        kind: AppNoticeKind.error,
      );
    }
  }

  Future<void> _restoreSubscription(String userId) async {
    try {
      if (!ref.read(appConfigProvider).useMockData) {
        await ref.read(publicProfileRepositoryProvider).like(userId);
        ref.invalidate(profileSubscriptionsProvider);
      }
      if (!mounted) return;
      setState(() => _removedSubscriptionIds.remove(userId));
    } on Object {
      if (!mounted) return;
      showAppNotice(context, 'Не удалось вернуть подписку');
    }
  }
}

class _MyRoutesListSkeleton extends StatelessWidget {
  const _MyRoutesListSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
      sliver: SliverToBoxAdapter(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return AppShimmer(
              child: Column(
                children: [
                  AppSkeleton(width: width, height: 295),
                  const SizedBox(height: 16),
                  AppSkeleton(width: width, height: 295),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FavoriteRouteTile extends StatelessWidget {
  const _FavoriteRouteTile({
    required this.route,
    required this.onRemove,
    super.key,
  });

  final RouteSummary route;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    return _FavoriteSwipeTile(
      itemId: route.id,
      semanticLabel: '${route.name}, маршрут в избранном',
      onRemove: onRemove,
      childBuilder: (remove) => SizedBox(
        height: 295,
        child: RouteHeroCard(
          route: route,
          height: 295,
          onFavoriteToggle: remove,
        ),
      ),
    );
  }
}

class _FavoriteSwipeTile extends StatefulWidget {
  const _FavoriteSwipeTile({
    required this.itemId,
    required this.semanticLabel,
    required this.onRemove,
    required this.childBuilder,
    super.key,
  });

  final String itemId;
  final String semanticLabel;
  final Future<void> Function() onRemove;
  final Widget Function(Future<void> Function() remove) childBuilder;

  @override
  State<_FavoriteSwipeTile> createState() => _FavoriteSwipeTileState();
}

class _FavoriteSwipeTileState extends State<_FavoriteSwipeTile> {
  static const _actionWidth = 104.0;
  static const _openThreshold = 32.0;
  static const _autoRemoveFraction = 0.72;

  double _offset = 0;
  double _cardWidth = 1;
  bool _dragging = false;
  bool _leaving = false;
  bool _collapsed = false;

  Duration get _settleDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 240);

  Duration get _collapseDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 190);

  void _onDragStart(DragStartDetails details) {
    if (_leaving) return;
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_leaving) return;
    final delta = details.primaryDelta ?? 0;
    setState(() => _offset = (_offset + delta).clamp(-_cardWidth, 0));
  }

  void _onDragEnd(DragEndDetails details) {
    if (_leaving) return;
    final distance = -_offset;
    if (distance >= _cardWidth * _autoRemoveFraction) {
      setState(() => _dragging = false);
      unawaited(_animateRemove());
      return;
    }
    setState(() {
      _dragging = false;
      _offset = distance >= _openThreshold ? -_actionWidth : 0;
    });
  }

  Future<void> _animateRemove() async {
    if (_leaving) return;
    unawaited(AppHaptics.mediumImpact());
    setState(() {
      _leaving = true;
      _dragging = false;
      _offset = -_cardWidth;
    });
    await Future<void>.delayed(_settleDuration);
    if (!mounted) return;
    setState(() => _collapsed = true);
    await Future<void>.delayed(_collapseDuration);
    if (!mounted) return;
    await widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      hint: 'Смахните влево или нажмите «Убрать»',
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Удалить из избранного'): () {
          unawaited(_animateRemove());
        },
      },
      child: AnimatedSize(
        duration: _collapseDuration,
        curve: AppMotion.emphasizedCurve,
        alignment: Alignment.topCenter,
        child: _collapsed
            ? const SizedBox(width: double.infinity)
            : LayoutBuilder(
                builder: (context, constraints) {
                  _cardWidth = constraints.maxWidth;
                  final reveal = (-_offset / _actionWidth).clamp(0.0, 1.0);
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _FavoriteRemoveBackground(
                            progress: reveal,
                            onRemove: _animateRemove,
                          ),
                        ),
                        AnimatedContainer(
                          key: ValueKey('favorite-dismiss-${widget.itemId}'),
                          duration: _dragging ? Duration.zero : _settleDuration,
                          curve: AppMotion.liquidOut,
                          transform: Matrix4.translationValues(_offset, 0, 0),
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragStart: _onDragStart,
                            onHorizontalDragUpdate: _onDragUpdate,
                            onHorizontalDragEnd: _onDragEnd,
                            child: widget.childBuilder(_animateRemove),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _FavoriteRemoveBackground extends StatelessWidget {
  const _FavoriteRemoveBackground({
    required this.progress,
    required this.onRemove,
  });

  final double progress;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final reveal = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: ColoredBox(
        key: const ValueKey('favorite-remove-background'),
        color: Color.lerp(
          Colors.transparent,
          AppColors.negativeSwipeTint,
          reveal,
        )!,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxHeight < 72 || constraints.maxWidth < 100) {
              return const SizedBox.shrink();
            }
            return Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: _FavoriteSwipeTileState._actionWidth,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('favorite-remove-action'),
                    onTap: onRemove,
                    child: Transform.scale(
                      scale: 0.72 + 0.28 * reveal,
                      child: Opacity(
                        opacity: 0.45 + 0.55 * reveal,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.heart_broken_rounded,
                              color: Colors.white,
                              size: 29,
                            ),
                            SizedBox(height: 7),
                            Text(
                              'Убрать',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Rubik',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ExecutionHistoryTile extends ConsumerWidget {
  const _ExecutionHistoryTile({required this.execution});

  final RouteExecution execution;

  /// An active run whose route no longer exists cannot be continued, and the
  /// backend refuses to start any new route while it is open. Without a way
  /// out of it here the account is simply stuck, so offer to end it.
  Future<void> _endOrphaned(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Завершить прохождение?'),
        content: const Text(
          'Маршрут был удалён, поэтому продолжить это прохождение нельзя. '
          'Завершите его, чтобы начать новый маршрут.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(routeExecutionRepositoryProvider).cancel(execution.id);
      ref.invalidate(routeExecutionHistoryProvider);
      ref.invalidate(activeRouteExecutionProvider);
      if (context.mounted) {
        showAppNotice(context, 'Прохождение завершено');
      }
    } on Object {
      if (context.mounted) {
        showAppNotice(context, 'Не удалось завершить. Попробуйте ещё раз.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeId = execution.routeId;
    final orphanedActive =
        routeId == null && execution.status == RouteExecutionStatus.active;
    final statusColor = switch (execution.status) {
      RouteExecutionStatus.completed => AppColors.positiveSwipeTint,
      RouteExecutionStatus.cancelled => AppColors.secondaryInk,
      RouteExecutionStatus.active => AppColors.accentBlue,
    };
    final statusLabel = switch (execution.status) {
      RouteExecutionStatus.completed => 'Завершён',
      RouteExecutionStatus.cancelled => 'Остановлен',
      RouteExecutionStatus.active => 'В процессе',
    };
    final date = execution.startedAt;
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

    return Material(
      color: AppColors.elevatedSurface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        onTap: routeId != null
            ? () => context.push('/routes/$routeId')
            : orphanedActive
            ? () => _endOrphaned(context, ref)
            : null,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(
                    execution.status == RouteExecutionStatus.completed
                        ? Icons.check_rounded
                        : execution.status == RouteExecutionStatus.active
                        ? Icons.directions_walk_rounded
                        : Icons.pause_rounded,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      execution.routeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.settingsRowTitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      orphanedActive
                          ? 'Маршрут удалён · нажмите, чтобы завершить'
                          : '$statusLabel · $dateLabel',
                      style: AppTypography.settingsRowSubtitle,
                    ),
                    if (execution.totalStops > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${execution.completedStops} из ${execution.totalStops} остановок',
                        style: AppTypography.routeMetadata,
                      ),
                    ],
                  ],
                ),
              ),
              if (routeId != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.secondaryInk,
                )
              else if (orphanedActive)
                const Icon(Icons.close_rounded, color: AppColors.secondaryInk),
            ],
          ),
        ),
      ),
    );
  }
}
