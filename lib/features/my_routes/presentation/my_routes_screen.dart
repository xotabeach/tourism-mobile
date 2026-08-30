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
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_providers.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/routes/application/route_catalog_filter.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/search/presentation/in_place_search.dart';
import 'package:tourism_mobile/features/search/presentation/universal_search_panel.dart';
import 'package:tourism_mobile/routing/app_router.dart';
import 'package:tourism_mobile/routing/shell/tab_scroll_to_top.dart';

enum MyRoutesTab { favorites, history, places, subscriptions }

/// 4-й раздел nav bar: избранное / история / места / подписки.
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
  var _selectedChip = 'Все';
  final _removedSubscriptionIds = <String>{};

  bool get _searchActive => _searchFocused || _searchQuery.isNotEmpty;

  Future<void> _openFilters() async {
    // Filters must apply the instant a filter is tapped — not after some
    // separate confirm step — so update the screen's own state directly
    // from the sheet's onTap instead of waiting on the sheet's pop result.
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final filter in routeCatalogFilters)
                    ListTile(
                      title: Text(filter),
                      trailing: filter == _selectedChip
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () {
                        setState(() => _selectedChip = filter);
                        setSheetState(() {});
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                ],
              );
            },
          ),
        );
      },
    );
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
    final routes = routesAsync.valueOrNull?.items ?? const <RouteSummary>[];
    final favoriteRoutes = routes
        .where((r) => favorites.routeIds.contains(r.id))
        .toList();
    final favoritePlaces =
        placesAsync.valueOrNull?.items
            .where((p) => favorites.placeIds.contains(p.id))
            .toList() ??
        const <PlaceSummary>[];
    final filtered = filterRouteCatalog(switch (_tab) {
      MyRoutesTab.favorites => favoriteRoutes,
      MyRoutesTab.history => const <RouteSummary>[],
      MyRoutesTab.places => const <RouteSummary>[],
      MyRoutesTab.subscriptions => const <RouteSummary>[],
    }, _selectedChip);

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
                      filterApplied: _selectedChip != 'Все',
                    ),
                    const SizedBox(height: 14),
                    _TabRow(
                      selected: _tab,
                      onChanged: (tab) => setState(() => _tab = tab),
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
                    scope: switch (_tab) {
                      MyRoutesTab.subscriptions => SearchScope.profiles,
                      MyRoutesTab.places => SearchScope.places,
                      MyRoutesTab.favorites ||
                      MyRoutesTab.history => SearchScope.routes,
                    },
                    localRoutes: switch (_tab) {
                      MyRoutesTab.favorites => favoriteRoutes,
                      MyRoutesTab.history => null,
                      MyRoutesTab.places || MyRoutesTab.subscriptions => null,
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
              ..._subscriptionSlivers(visibleSubscriptionsAsync)
            else if (_tab == MyRoutesTab.places)
              ..._placesSlivers(placesAsync, favoritePlaces: favoritePlaces)
            else if (_tab == MyRoutesTab.history)
              ..._executionHistorySlivers(historyAsync)
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

class _TabRow extends StatelessWidget {
  const _TabRow({required this.selected, required this.onChanged});

  final MyRoutesTab selected;
  final ValueChanged<MyRoutesTab> onChanged;

  @override
  Widget build(BuildContext context) {
    const firstRow = [MyRoutesTab.favorites, MyRoutesTab.subscriptions];
    const secondRow = [MyRoutesTab.places, MyRoutesTab.history];
    return Column(
      children: [
        Row(
          children: [
            for (final tab in firstRow) ...[
              if (tab != firstRow.first) const SizedBox(width: 8),
              Expanded(
                child: _TabChip(
                  label: switch (tab) {
                    MyRoutesTab.favorites => 'Маршруты',
                    MyRoutesTab.history => 'История',
                    MyRoutesTab.places => 'Места',
                    MyRoutesTab.subscriptions => 'Подписки',
                  },
                  selected: selected == tab,
                  onTap: () => onChanged(tab),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final tab in secondRow) ...[
              if (tab != secondRow.first) const SizedBox(width: 8),
              Expanded(
                child: _TabChip(
                  label: switch (tab) {
                    MyRoutesTab.favorites => 'Маршруты',
                    MyRoutesTab.history => 'История',
                    MyRoutesTab.places => 'Места',
                    MyRoutesTab.subscriptions => 'Подписки',
                  },
                  selected: selected == tab,
                  onTap: () => onChanged(tab),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentBlue : AppColors.elevatedSurface,
      borderRadius: BorderRadius.circular(AppRadii.capsule),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.capsule),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.capsule),
            border: selected ? null : Border.all(color: AppColors.hairline),
          ),
          child: Text(
            label,
            style: AppTypography.settingsRowTitle.copyWith(
              fontSize: 14,
              color: selected ? Colors.white : AppColors.primaryInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExecutionHistoryTile extends StatelessWidget {
  const _ExecutionHistoryTile({required this.execution});

  final RouteExecution execution;

  @override
  Widget build(BuildContext context) {
    final routeId = execution.routeId;
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
        onTap: routeId == null ? null : () => context.push('/routes/$routeId'),
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
                      '$statusLabel · $dateLabel',
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}
