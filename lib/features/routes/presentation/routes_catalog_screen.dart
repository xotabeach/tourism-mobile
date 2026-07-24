import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/theme/app_colors.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(routesListProvider);

    return Scaffold(
      backgroundColor: AppColors.mist,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 84, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: 'Искать маршруты и места',
                            prefixIcon: Icon(Icons.search, size: 34),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 17,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: AppColors.mistDark,
                        shape: const CircleBorder(),
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.tune_rounded),
                          iconSize: 30,
                          padding: const EdgeInsets.all(15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 54,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _chips.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final chip = _chips[index];
                        final selected = chip == _selectedChip;
                        return FilterChip(
                          selected: selected,
                          showCheckmark: false,
                          label: Text(
                            chip,
                            style: TextStyle(
                              color: selected ? Colors.white : AppColors.ink,
                            ),
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedChip = chip),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: routesAsync.when(
                data: (page) {
                  if (page.items.isEmpty) {
                    return const Center(child: Text('Маршруты не найдены'));
                  }
                  return PageView.builder(
                    controller: PageController(viewportFraction: 0.9),
                    itemCount: page.items.length,
                    itemBuilder: (context, index) {
                      return Transform.rotate(
                        angle: index == 0 ? -0.035 : 0.025,
                        child: RouteHeroCard(
                          route: page.items[index],
                          height: double.infinity,
                          tags: index == 0
                              ? const ['Горы', 'С детьми', 'Пешком']
                              : const [],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Ошибка: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
