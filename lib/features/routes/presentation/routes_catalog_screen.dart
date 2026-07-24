import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_swipe_deck.dart';

class RoutesCatalogScreen extends ConsumerStatefulWidget {
  const RoutesCatalogScreen({super.key});

  static const routePath = '/routes';

  @override
  ConsumerState<RoutesCatalogScreen> createState() =>
      _RoutesCatalogScreenState();
}

class _RoutesCatalogScreenState extends ConsumerState<RoutesCatalogScreen> {
  static const _chips = ['Все', 'Море', 'Горы', 'Еда', 'Лес'];
  var _selectedChip = 'Все';
  var _showCoach = true;

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(routesListProvider);
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
                AppSearchFilterRow(onSearchTap: () {}, onFilterTap: () {}),
                const SizedBox(height: AppSpacing.md),
                AppFilterChipBar(
                  labels: _chips,
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
                if (page.items.isEmpty) {
                  return const Center(child: Text('Маршруты не найдены'));
                }
                return RouteSwipeDeck(
                  routes: page.items,
                  showCoach: _showCoach,
                  onCoachDismiss: () => setState(() => _showCoach = false),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Ошибка: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
