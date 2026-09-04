import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/places/presentation/widgets/place_hero_card.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_menu_bubble.dart';
import 'package:tourism_mobile/features/search/presentation/in_place_search.dart';

/// What the Home feed (and this screen) is currently listing.
enum HomeListMode { routes, places }

const _pageSize = 10;

/// Explicit sort choices offered from the sort button. `null` (no choice
/// made) keeps each mode's existing default order — routes stay
/// popularity-sorted and places stay name-sorted, exactly as before this
/// control existed — so adding sorting doesn't change anyone's first
/// impression of either list.
enum _SortOption {
  dateNewest('Сначала новые', Icons.arrow_downward_rounded),
  dateOldest('Сначала старые', Icons.arrow_upward_rounded),
  nameAsc('По названию (А–Я)', Icons.sort_by_alpha_rounded),
  nameDesc('По названию (Я–А)', Icons.sort_by_alpha_rounded);

  const _SortOption(this.label, this.icon);

  final String label;
  final IconData icon;

  RouteCatalogSort get routeSort => switch (this) {
    _SortOption.dateNewest => RouteCatalogSort.dateNewest,
    _SortOption.dateOldest => RouteCatalogSort.dateOldest,
    _SortOption.nameAsc => RouteCatalogSort.nameAsc,
    _SortOption.nameDesc => RouteCatalogSort.nameDesc,
  };

  PlaceCatalogSort get placeSort => switch (this) {
    _SortOption.dateNewest => PlaceCatalogSort.dateNewest,
    _SortOption.dateOldest => PlaceCatalogSort.dateOldest,
    _SortOption.nameAsc => PlaceCatalogSort.nameAsc,
    _SortOption.nameDesc => PlaceCatalogSort.nameDesc,
  };
}

/// Full Маршруты/Локации list reached from Home's "Смотреть все". Unlike the
/// Home feed and the routes/places catalog tabs (which fetch everything in
/// one call), this screen paginates: 10 items per page, loading more as the
/// user scrolls near the bottom — the first incremental-fetch screen in the
/// app, since the catalog screens have no precedent for it yet.
class AllListScreen extends ConsumerStatefulWidget {
  const AllListScreen({required this.initialMode, super.key});

  static const routePath = 'all';

  final HomeListMode initialMode;

  @override
  ConsumerState<AllListScreen> createState() => _AllListScreenState();
}

class _AllListScreenState extends ConsumerState<AllListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'all-list-search');
  final _sortAnchorKey = GlobalKey();
  Timer? _searchDebounce;
  late HomeListMode _mode;
  _SortOption? _sort;
  final _routeItems = <RouteSummary>[];
  final _placeItems = <PlaceSummary>[];
  var _offset = 0;
  var _total = 0;
  var _loading = false;
  var _loadGeneration = 0;
  var _error = false;
  var _searchQuery = '';
  var _searchFocused = false;

  bool get _searchActive => _searchFocused || _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _scrollController.addListener(_onScroll);
    _searchFocus.addListener(() {
      if (mounted) {
        setState(() => _searchFocused = _searchFocus.hasFocus);
      }
    });
    unawaited(_loadNextPage());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchDebounce?.cancel();
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      setState(() => _searchQuery = value.trim());
    });
  }

  bool get _hasMore => _mode == HomeListMode.routes
      ? _routeItems.length < _total
      : _placeItems.length < _total;

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels + 200 >= position.maxScrollExtent) {
      unawaited(_loadNextPage());
    }
  }

  Future<void> _loadNextPage() async {
    final generation = _loadGeneration;
    final mode = _mode;
    final offset = _offset;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      if (mode == HomeListMode.routes) {
        final page = await ref
            .read(routesRepositoryProvider)
            .listRoutes(
              regionSlug: 'crimea',
              limit: _pageSize,
              offset: offset,
              sort: _sort?.routeSort ?? RouteCatalogSort.popular,
            );
        if (!mounted || generation != _loadGeneration || mode != _mode) return;
        setState(() {
          _routeItems.addAll(page.items);
          _total = page.total;
          _offset = _routeItems.length;
        });
      } else {
        final page = await ref
            .read(placesRepositoryProvider)
            .listPlaces(
              regionSlug: 'crimea',
              limit: _pageSize,
              offset: offset,
              sort: _sort?.placeSort ?? PlaceCatalogSort.defaultOrder,
            );
        if (!mounted || generation != _loadGeneration || mode != _mode) return;
        setState(() {
          _placeItems.addAll(page.items);
          _total = page.total;
          _offset = _placeItems.length;
        });
      }
    } on Object {
      if (mounted && generation == _loadGeneration && mode == _mode) {
        setState(() => _error = true);
      }
    } finally {
      if (mounted && generation == _loadGeneration && mode == _mode) {
        setState(() => _loading = false);
      }
    }
  }

  void _switchMode(HomeListMode mode) {
    if (mode == _mode) return;
    _searchDebounce?.cancel();
    _searchController.clear();
    _loadGeneration++;
    setState(() {
      _mode = mode;
      _routeItems.clear();
      _placeItems.clear();
      _offset = 0;
      _total = 0;
      _error = false;
      _searchQuery = '';
    });
    unawaited(_loadNextPage());
  }

  /// Полная перезагрузка списка с первой страницы — для «потянуть вниз».
  Future<void> _refresh() async {
    _loadGeneration++;
    setState(() {
      _routeItems.clear();
      _placeItems.clear();
      _offset = 0;
      _total = 0;
      _error = false;
    });
    await _loadNextPage();
  }

  void _changeSort(_SortOption? option) {
    if (option == _sort) return;
    _loadGeneration++;
    setState(() {
      _sort = option;
      _routeItems.clear();
      _placeItems.clear();
      _offset = 0;
      _total = 0;
      _error = false;
    });
    unawaited(_loadNextPage());
  }

  void _openSort() {
    unawaited(
      showRouteMenuBubble(
        context: context,
        anchorKey: _sortAnchorKey,
        actions: [
          for (final option in _SortOption.values)
            RouteMenuAction(
              icon: option.icon,
              label: option.label,
              selected: _sort == option,
              onSelected: () => _changeSort(_sort == option ? null : option),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _mode == HomeListMode.routes
        ? _routeItems.length
        : _placeItems.length;

    return Scaffold(
      backgroundColor: AppColors.mist,
      appBar: AppBar(
        backgroundColor: AppColors.mist,
        elevation: 0,
        title: Text(
          _mode == HomeListMode.routes ? 'Маршруты' : 'Локации',
          style: AppTypography.sectionTitle,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              4,
              AppSpacing.page,
              14,
            ),
            child: Column(
              children: [
                AppSegmentedToggle(
                  labels: const ['Маршруты', 'Локации'],
                  selected: _mode == HomeListMode.routes
                      ? 'Маршруты'
                      : 'Локации',
                  onSelected: (label) => _switchMode(
                    label == 'Маршруты'
                        ? HomeListMode.routes
                        : HomeListMode.places,
                  ),
                ),
                const SizedBox(height: 14),
                AppSearchFilterRow(
                  showFilterButton: !_searchActive,
                  filterButtonKey: _sortAnchorKey,
                  filterSemanticLabel: 'Сортировка',
                  filterApplied: _sort != null,
                  onFilterTap: _openSort,
                  hintText: _mode == HomeListMode.routes
                      ? 'Искать маршруты'
                      : 'Искать локации',
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onSearchChanged: _onSearchChanged,
                  onSearchClear: () {
                    _searchDebounce?.cancel();
                    setState(() => _searchQuery = '');
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _searchActive
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      0,
                      AppSpacing.page,
                      AppSpacing.shellBottomContent,
                    ),
                    child: InPlaceSearchBody(
                      query: _searchQuery,
                      scope: _mode == HomeListMode.routes
                          ? SearchScope.routes
                          : SearchScope.places,
                      onQueryFromHistory: (value) {
                        _searchController.text = value;
                        _onSearchChanged(value);
                      },
                    ),
                  )
                : itemCount == 0 && _loading
                ? const Center(child: CircularProgressIndicator())
                : itemCount == 0 && _error
                ? Center(
                    child: TextButton.icon(
                      onPressed: () => unawaited(_loadNextPage()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Не удалось загрузить, повторить'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        0,
                        AppSpacing.page,
                        AppSpacing.shellBottomContent,
                      ),
                      itemCount: itemCount + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= itemCount) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _mode == HomeListMode.routes
                              ? RouteHeroCard(
                                  route: _routeItems[index],
                                  height: 304,
                                )
                              : PlaceHeroCard(place: _placeItems[index]),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
