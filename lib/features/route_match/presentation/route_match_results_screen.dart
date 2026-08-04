import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

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
  final _searchFocus = FocusNode(debugLabel: 'match-results-search');
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
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
          final q = _query.toLowerCase();
          final filtered = q.isEmpty
              ? routes
              : routes.where((r) => r.name.toLowerCase().contains(q)).toList();
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
                        controller: _searchController,
                        focusNode: _searchFocus,
                        hintText: 'Место или маршрут из подборки',
                        onSearchChanged: (value) =>
                            setState(() => _query = value.trim()),
                        onSearchClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        onSearchDismiss: _searchFocus.unfocus,
                        onFilterTap: () {},
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Идеально для вас:',
                        style: AppTypography.sectionTitle.copyWith(
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
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
                      style: AppTypography.sectionTitle.copyWith(fontSize: 17),
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
          );
        },
      ),
    );
  }
}
