import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/search/presentation/in_place_search.dart';

/// Результат подбора маршрута (UI + данные из каталога как mock).
class RouteMatchResultsScreen extends ConsumerStatefulWidget {
  const RouteMatchResultsScreen({super.key});

  static const routePath = 'results';

  @override
  ConsumerState<RouteMatchResultsScreen> createState() =>
      _RouteMatchResultsScreenState();
}

class _RouteMatchResultsScreenState
    extends ConsumerState<RouteMatchResultsScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'match-search');
  Timer? _searchDebounce;
  var _searchQuery = '';
  var _searchFocused = false;

  bool get _searchActive => _searchFocused || _searchQuery.isNotEmpty;

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
      final query = value.trim();
      setState(() => _searchQuery = query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final routesAsync = ref.watch(routesListProvider);

    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      body: routesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (page) {
          final routes = page.items;
          final filtered = routes;
          final ideal = filtered.take(3).toList();
          final close = filtered.skip(3).take(3).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, top + 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          ),
                          Expanded(
                            child: Text(
                              'Результаты подбора (${filtered.length})',
                              style: AppTypography.sectionTitle.copyWith(
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AppSearchFilterRow(
                        hintText: 'Место или маршрут из подборки',
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onSearchChanged: _onSearchChanged,
                        onSearchClear: () {
                          _searchDebounce?.cancel();
                          setState(() => _searchQuery = '');
                        },
                        onFilterTap: () {},
                      ),
                      if (!_searchActive) ...[
                        const SizedBox(height: 18),
                        Text(
                          'Идеально для вас:',
                          style: AppTypography.sectionTitle.copyWith(
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              if (_searchActive)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  sliver: SliverToBoxAdapter(
                    child: InPlaceSearchBody(
                      query: _searchQuery,
                      scope: SearchScope.routes,
                      localRoutes: filtered,
                      onQueryFromHistory: (value) {
                        _searchController.text = value;
                        _onSearchChanged(value);
                      },
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: ideal.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) =>
                        RouteHeroCard(route: ideal[index], height: 295),
                  ),
                ),
                if (close.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Близки к вашему идеалу:',
                        style: AppTypography.sectionTitle.copyWith(
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList.separated(
                      itemCount: close.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) =>
                          RouteHeroCard(route: close[index], height: 295),
                    ),
                  ),
                ] else
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ],
          );
        },
      ),
    );
  }
}
