import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/theme/app_colors.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const routePath = '/';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _chips = ['Все', 'Море', 'Горы', 'Еда', 'Лес'];
  var _selectedChip = 'Все';

  List<RouteSummary> _filtered(List<RouteSummary> items) {
    if (_selectedChip == 'Все') {
      return items;
    }
    final needle = _selectedChip.toLowerCase();
    return items.where((route) {
      final haystack =
          '${route.name} ${route.shortDescription ?? ''} ${route.difficulty ?? ''} ${route.transportMode ?? ''}'
              .toLowerCase();
      return switch (needle) {
        'море' =>
          haystack.contains('берег') ||
              haystack.contains('ялт') ||
              haystack.contains('мор'),
        'горы' =>
          haystack.contains('гор') ||
              haystack.contains('бахчисар') ||
              haystack.contains('кале'),
        'еда' => haystack.contains('еда') || haystack.contains('кухн'),
        'лес' => haystack.contains('лес') || haystack.contains('троп'),
        _ => true,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final routesAsync = ref.watch(routesListProvider);
    final name = (session.displayName?.trim().isNotEmpty ?? false)
        ? session.displayName!.trim()
        : 'путник';

    return Scaffold(
      backgroundColor: AppColors.mist,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.mistDark,
                          backgroundImage: AssetImage(
                            AppImages.travelerPortrait,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Привет, $name!',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Может пройдемся?',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: AppColors.mistDark,
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.notifications_none_rounded),
                            iconSize: 30,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 34),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            onTap: () => context.goNamed(AppRouteNames.routes),
                            decoration: const InputDecoration(
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
                            onPressed: () =>
                                context.goNamed(AppRouteNames.places),
                            icon: const Icon(Icons.tune_rounded),
                            iconSize: 30,
                            padding: const EdgeInsets.all(15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 34),
                    const BuildRouteBanner(),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Топ путешественников',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(fontSize: 22),
                          ),
                        ),
                        Text(
                          'Весь топ',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _TopTravelersRow(),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Маршруты',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(fontSize: 24),
                          ),
                        ),
                        Text(
                          'Листать все',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            routesAsync.when(
              data: (page) {
                final items = _filtered(page.items);
                if (items.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Маршруты не найдены')),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 104),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return RouteHeroCard(
                        route: items[index],
                        height: 360,
                        tags: index == 0
                            ? const ['Горы', 'С детьми', 'Пешком']
                            : const [],
                      );
                    },
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Ошибка: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopTravelersRow extends StatelessWidget {
  const _TopTravelersRow();

  static const _travelers = [
    ('ТОП 1', '12 500 тп', Color(0xFFFFD400)),
    ('ТОП 2', '10 480 тп', Color(0xFFCFCFCF)),
    ('ТОП 3', '8 120 тп', Color(0xFFFFB35C)),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _travelers.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _travelers[i].$3, width: 2.5),
                    ),
                    child: const CircleAvatar(
                      backgroundImage: AssetImage(AppImages.travelerPortrait),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _travelers[i].$1,
                    style: Theme.of(context).textTheme.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _travelers[i].$2,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
