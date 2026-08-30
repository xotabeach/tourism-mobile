import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/features/home/presentation/all_list_screen.dart';
import 'package:tourism_mobile/features/recommendations/application/recommendation_providers.dart';
import 'package:tourism_mobile/features/recommendations/domain/recommendation.dart';
import 'package:tourism_mobile/features/routes/application/favorite_routes_provider.dart';
import 'package:tourism_mobile/features/routes/application/route_catalog_filter.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_menu_bubble.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_swipe_deck.dart';
import 'package:tourism_mobile/features/search/presentation/in_place_search.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class RoutesCatalogScreen extends ConsumerStatefulWidget {
  const RoutesCatalogScreen({super.key});

  static const routePath = '/routes';

  @override
  ConsumerState<RoutesCatalogScreen> createState() =>
      _RoutesCatalogScreenState();
}

class _RoutesCatalogScreenState extends ConsumerState<RoutesCatalogScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'routes-search');
  Timer? _searchDebounce;
  var _selectedChip = 'Все';
  // Anchors the deck-settings popover to the filter button.
  final _filterAnchorKey = GlobalKey();
  var _showCoach = true;
  var _searchQuery = '';
  var _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (mounted) {
        setState(() => _searchFocused = _searchFocus.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
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

  List<RouteSummary> _visibleRoutes(
    List<RouteSummary> items,
    Set<String> favoriteRouteIds,
  ) {
    // Already-favorited routes have nothing left to decide — swiping on one
    // again is pointless, so keep them out of the deck entirely.
    final undecided = items.where(
      (route) => !favoriteRouteIds.contains(route.id),
    );
    return filterRouteCatalog(undecided.toList(), _selectedChip);
  }

  Future<void> _openFilters() async {
    // Category filters already live in the chip bar under the search field;
    // repeating them here just gave two places to change the same thing.
    // This popover is for what the deck itself shows.
    await showRouteMenuBubble(
      context: context,
      anchorKey: _filterAnchorKey,
      actions: [
        RouteMenuAction(
          icon: Icons.auto_awesome_outlined,
          label: 'Показывать рекомендации',
          toggleValue: () => ref.read(showRecommendationsProvider),
          onSelected: () {
            final notifier = ref.read(showRecommendationsProvider.notifier);
            notifier.state = !notifier.state;
            setState(() {});
          },
        ),
        RouteMenuAction(
          icon: Icons.refresh_rounded,
          label: 'Обновить рекомендации',
          onSelected: () => unawaited(_refreshRecommendations()),
        ),
      ],
    );
  }

  Future<void> _refreshRecommendations() async {
    try {
      await refreshRecommendationDeck(ref);
      if (mounted) {
        _notify('Рекомендации обновлены');
      }
    } on Object {
      if (mounted) {
        _notify('Не удалось обновить рекомендации');
      }
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleSwipe(
    RouteSummary route,
    RouteSwipeAction action, {
    RecommendationDeck? recommendationDeck,
  }) {
    if (action == RouteSwipeAction.favorite) {
      unawaited(ref.read(favoritesProvider.notifier).addRoute(route.id));
    } else if (recommendationDeck != null) {
      unawaited(
        submitRecommendationSkip(
          ref,
          routeId: route.id,
          deckDate: recommendationDeck.deckDate,
          rankerVersion: recommendationDeck.rankerVersion,
        ).catchError((_) {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(routesListProvider);
    final showRecommendations = ref.watch(showRecommendationsProvider);
    final recommendationAsync = ref.watch(recommendationDeckProvider);
    final recommendationDeck = showRecommendations
        ? recommendationAsync.valueOrNull
        : null;
    final favoriteRouteIds = ref.watch(favoriteRouteIdsProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: AppColors.mist,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page,
              topInset + AppSpacing.sm,
              AppSpacing.page,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSearchFilterRow(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  hintText: 'Искать маршруты',
                  onSearchChanged: _onSearchChanged,
                  onSearchClear: () {
                    _searchDebounce?.cancel();
                    setState(() => _searchQuery = '');
                  },
                  filterButtonKey: _filterAnchorKey,
                  onFilterTap: () => unawaited(_openFilters()),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!(_searchFocused || _searchQuery.isNotEmpty))
                  AppFilterChipBar(
                    labels: routeCatalogFilters,
                    selected: _selectedChip,
                    onSelected: (chip) {
                      setState(() => _selectedChip = chip);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: (_searchFocused || _searchQuery.isNotEmpty)
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      0,
                      AppSpacing.page,
                      96,
                    ),
                    child: InPlaceSearchBody(
                      query: _searchQuery,
                      scope: SearchScope.routes,
                      onQueryFromHistory: (value) {
                        _searchController.text = value;
                        _onSearchChanged(value);
                      },
                    ),
                  )
                : routesAsync.when(
                    skipLoadingOnReload: true,
                    skipLoadingOnRefresh: true,
                    skipError: true,
                    data: (page) {
                      final recommendedItems = recommendationDeck?.items
                          .map((item) => item.route)
                          .toList(growable: false);
                      final visibleRoutes = _visibleRoutes(
                        recommendedItems != null && recommendedItems.isNotEmpty
                            ? recommendedItems
                            : page.items,
                        favoriteRouteIds,
                      );
                      if (visibleRoutes.isEmpty) {
                        return const Center(child: Text('Маршруты не найдены'));
                      }
                      // Re-key on the active filter/source so switching
                      // them animates the old cards out and the new ones in
                      // instead of swapping content under the user's finger.
                      return AnimatedSwitcher(
                        duration: AppMotion.emphasized,
                        switchInCurve: AppMotion.emphasizedCurve,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.06, 0.03),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: RouteSwipeDeck(
                          key: ValueKey('$_selectedChip|$showRecommendations'),
                          routes: visibleRoutes,
                          onSwipe: (route, action) => _handleSwipe(
                            route,
                            action,
                            recommendationDeck: recommendationDeck,
                          ),
                          recommendationReasons: {
                            for (final item
                                in recommendationDeck?.items ??
                                    const <RecommendationCard>[])
                              item.route.id: recommendationExplanationLabel(
                                item.explanation,
                              ),
                          },
                          onOpenAllRoutes: () => unawaited(
                            context.pushNamed(
                              AppRouteNames.homeAllList,
                              extra: HomeListMode.routes,
                            ),
                          ),
                          showCoach: _showCoach,
                          onCoachDismiss: () =>
                              setState(() => _showCoach = false),
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => AppAsyncErrorView(
                      onRetry: () => ref.invalidate(routesListProvider),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
