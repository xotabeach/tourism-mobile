import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/theme/app_colors.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class PlacesCatalogScreen extends ConsumerStatefulWidget {
  const PlacesCatalogScreen({super.key});

  static const routePath = '/places';

  @override
  ConsumerState<PlacesCatalogScreen> createState() =>
      _PlacesCatalogScreenState();
}

class _PlacesCatalogScreenState extends ConsumerState<PlacesCatalogScreen> {
  static const _chips = ['Все', 'Природа', 'Смотровые', 'История', 'Платно'];
  var _selectedChip = 'Все';

  List<PlaceSummary> _filtered(List<PlaceSummary> items) {
    if (_selectedChip == 'Все') {
      return items;
    }
    if (_selectedChip == 'Платно') {
      return items.where((place) => place.isPaid).toList();
    }
    final needle = _selectedChip.toLowerCase();
    return items
        .where(
          (place) => place.categories.any(
            (category) => category.name.toLowerCase().contains(needle),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(placesListProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Места Крыма',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Искать места и категории',
                        prefixIcon: Icon(Icons.search),
                        suffixIcon: Icon(Icons.tune_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
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
                  ],
                ),
              ),
            ),
            placesAsync.when(
              data: (page) {
                final items = _filtered(page.items);
                if (items.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Места не найдены')),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      return _PlaceCatalogCard(place: items[index]);
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

class _PlaceCatalogCard extends StatelessWidget {
  const _PlaceCatalogCard({required this.place});

  final PlaceSummary place;

  @override
  Widget build(BuildContext context) {
    final categories = place.categories.map((category) => category.name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.pushNamed(
          AppRouteNames.placeDetails,
          pathParameters: {'id': place.id},
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.mist,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(24),
                ),
                child: Image.asset(
                  AppImages.routeFallbackAsset(place.slug),
                  width: 116,
                  height: 142,
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              place.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        place.shortDescription ?? categories.join(', '),
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ...categories.take(2).map((label) {
                            return _SoftPill(label: label);
                          }),
                          if (place.difficulty != null)
                            _SoftPill(label: difficultyLabel(place.difficulty)),
                          if (place.isPaid) const _SoftPill(label: 'Платно'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftPill extends StatelessWidget {
  const _SoftPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
