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

/// What the Home feed (and this screen) is currently listing.
enum HomeListMode { routes, places }

const _pageSize = 10;

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
  late HomeListMode _mode;
  final _routeItems = <RouteSummary>[];
  final _placeItems = <PlaceSummary>[];
  var _offset = 0;
  var _total = 0;
  var _loading = false;
  var _error = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _scrollController.addListener(_onScroll);
    unawaited(_loadNextPage());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
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
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      if (_mode == HomeListMode.routes) {
        final page = await ref
            .read(routesRepositoryProvider)
            .listRoutes(
              regionSlug: 'crimea',
              limit: _pageSize,
              offset: _offset,
              sort: RouteCatalogSort.popular,
            );
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
              offset: _offset,
            );
        setState(() {
          _placeItems.addAll(page.items);
          _total = page.total;
          _offset = _placeItems.length;
        });
      }
    } on Object {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switchMode(HomeListMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _routeItems.clear();
      _placeItems.clear();
      _offset = 0;
      _total = 0;
      _error = false;
    });
    unawaited(_loadNextPage());
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
            child: AppSegmentedToggle(
              labels: const ['Маршруты', 'Локации'],
              selected: _mode == HomeListMode.routes ? 'Маршруты' : 'Локации',
              onSelected: (label) => _switchMode(
                label == 'Маршруты' ? HomeListMode.routes : HomeListMode.places,
              ),
            ),
          ),
          Expanded(
            child: itemCount == 0 && _loading
                ? const Center(child: CircularProgressIndicator())
                : itemCount == 0 && _error
                ? Center(
                    child: TextButton.icon(
                      onPressed: () => unawaited(_loadNextPage()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Не удалось загрузить, повторить'),
                    ),
                  )
                : ListView.builder(
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
        ],
      ),
    );
  }
}
