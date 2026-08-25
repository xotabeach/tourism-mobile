import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/features/home/presentation/all_list_screen.dart';
import 'package:tourism_mobile/features/routes/application/favorite_routes_provider.dart';
import 'package:tourism_mobile/features/routes/application/route_catalog_filter.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
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
    final undecided = items.where((route) => !favoriteRouteIds.contains(route.id));
    return filterRouteCatalog(undecided.toList(), _selectedChip);
  }

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

  void _handleSwipe(RouteSummary route, RouteSwipeAction action) {
    if (action == RouteSwipeAction.favorite) {
      unawaited(ref.read(favoritesProvider.notifier).addRoute(route.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(routesListProvider);
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
                  onFilterTap: () => unawaited(_openFilters()),
                  filterApplied: _selectedChip != 'Все',
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
                      final visibleRoutes = _visibleRoutes(
                        page.items,
                        favoriteRouteIds,
                      );
                      if (visibleRoutes.isEmpty) {
                        return const Center(child: Text('Маршруты не найдены'));
                      }
                      return RouteSwipeDeck(
                        routes: visibleRoutes,
                        onSwipe: _handleSwipe,
                        onOpenAllRoutes: () => unawaited(
                          context.pushNamed(
                            AppRouteNames.homeAllList,
                            extra: HomeListMode.routes,
                          ),
                        ),
                        showCoach: _showCoach,
                        onCoachDismiss: () =>
                            setState(() => _showCoach = false),
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
