import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/features/routes/application/favorite_routes_provider.dart';
import 'package:tourism_mobile/features/routes/application/route_catalog_filter.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_swipe_deck.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class RoutesCatalogScreen extends ConsumerStatefulWidget {
  const RoutesCatalogScreen({super.key});

  static const routePath = '/routes';

  @override
  ConsumerState<RoutesCatalogScreen> createState() =>
      _RoutesCatalogScreenState();
}

class _RoutesCatalogScreenState extends ConsumerState<RoutesCatalogScreen> {
  var _selectedChip = 'Все';
  var _showCoach = true;

  Future<void> _openSearch(List<RouteSummary> routes) async {
    if (routes.isEmpty) {
      return;
    }
    final selected = await showSearch<RouteSummary?>(
      context: context,
      delegate: _RouteSearchDelegate(routes),
    );
    if (!mounted || selected == null) {
      return;
    }
    unawaited(
      context.pushNamed(
        AppRouteNames.routeDetails,
        pathParameters: {'id': selected.id},
        extra: selected,
      ),
    );
  }

  Future<void> _openFilters() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final filter in routeCatalogFilters)
                ListTile(
                  title: Text(filter),
                  trailing: filter == _selectedChip
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(context).pop(filter),
                ),
            ],
          ),
        );
      },
    );
    if (mounted && selected != null) {
      setState(() => _selectedChip = selected);
    }
  }

  void _handleSwipe(RouteSummary route, RouteSwipeAction action) {
    if (action == RouteSwipeAction.favorite) {
      ref.read(favoriteRouteIdsProvider.notifier).add(route.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(routesListProvider);
    final routes = routesAsync.asData?.value.items ?? const <RouteSummary>[];
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
                  onSearchTap: () => unawaited(_openSearch(routes)),
                  onFilterTap: () => unawaited(_openFilters()),
                ),
                const SizedBox(height: AppSpacing.md),
                AppFilterChipBar(
                  labels: routeCatalogFilters,
                  selected: _selectedChip,
                  onSelected: (chip) => setState(() => _selectedChip = chip),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: routesAsync.when(
              data: (page) {
                final visibleRoutes = filterRouteCatalog(
                  page.items,
                  _selectedChip,
                );
                if (visibleRoutes.isEmpty) {
                  return const Center(child: Text('Маршруты не найдены'));
                }
                return RouteSwipeDeck(
                  routes: visibleRoutes,
                  onSwipe: _handleSwipe,
                  showCoach: _showCoach,
                  onCoachDismiss: () => setState(() => _showCoach = false),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
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

class _RouteSearchDelegate extends SearchDelegate<RouteSummary?> {
  _RouteSearchDelegate(this.routes);

  final List<RouteSummary> routes;

  @override
  String get searchFieldLabel => 'Маршруты и места';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          tooltip: 'Очистить',
          icon: const Icon(Icons.clear_rounded),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      tooltip: 'Назад',
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final matches = normalizedQuery.isEmpty
        ? routes
        : routes
              .where((route) {
                final searchable =
                    '${route.name} ${route.shortDescription ?? ''}'
                        .toLowerCase();
                return searchable.contains(normalizedQuery);
              })
              .toList(growable: false);
    if (matches.isEmpty) {
      return const Center(child: Text('Маршруты не найдены'));
    }
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final route = matches[index];
        return ListTile(
          title: Text(route.name),
          subtitle: route.shortDescription == null
              ? null
              : Text(
                  route.shortDescription!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          onTap: () => close(context, route),
        );
      },
    );
  }
}
