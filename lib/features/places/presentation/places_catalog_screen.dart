import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/cache/api_cache.dart';
import 'package:tourism_mobile/core/cache/app_data_refresh.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/theme/app_colors.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/routing/app_router.dart';
import 'package:tourism_mobile/routing/shell/tab_scroll_to_top.dart';

class PlacesCatalogScreen extends ConsumerStatefulWidget {
  const PlacesCatalogScreen({super.key});

  static const routePath = '/places';

  @override
  ConsumerState<PlacesCatalogScreen> createState() =>
      _PlacesCatalogScreenState();
}

class _PlacesCatalogScreenState extends ConsumerState<PlacesCatalogScreen> {
  static const _chips = ['Все', 'Природа', 'Смотровые', 'История', 'Платно'];
  static const _searchDelay = Duration(milliseconds: 300);

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'places-search');
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  var _selectedChip = 'Все';
  var _searchQuery = '';

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    syncTabScrolledDown(ref, 3, _scrollController.offset);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

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

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDelay, () => _applySearch(value));
  }

  void _applySearch(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (!mounted || query == _searchQuery) {
      return;
    }
    setState(() => _searchQuery = query);
  }

  void _clearSearch() {
    _searchController.clear();
    _applySearch('');
  }

  void _dismissSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchFocus.unfocus();
    _applySearch('');
  }

  Future<void> _refresh() async {
    if (_searchQuery.isEmpty) {
      await refreshAppData(ref, scope: AppDataRefreshScope.places);
      return;
    }
    ref.read(apiCacheRegistryProvider).invalidateAll();
    ref.invalidate(placesSearchProvider(_searchQuery));
    await ref.read(placesSearchProvider(_searchQuery).future);
  }

  void _retry() {
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(tabScrollToTopProvider(0), (previous, next) {
      if (!_scrollController.hasClients) {
        return;
      }
      unawaited(
        _scrollController.animateTo(
          0,
          duration: AppMotion.emphasized,
          curve: Curves.easeOutCubic,
        ),
      );
    });
    final placesAsync = _searchQuery.isEmpty
        ? ref.watch(placesListProvider)
        : ref.watch(placesSearchProvider(_searchQuery));

    return ColoredBox(
      color: AppColors.mist,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
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
                      AppSearchFilterRow(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        hintText: 'Искать места',
                        onSearchChanged: _scheduleSearch,
                        onSearchSubmitted: _applySearch,
                        onSearchClear: _clearSearch,
                        onSearchDismiss: _dismissSearch,
                        onFilterTap: () {},
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
                                  color: selected
                                      ? Colors.white
                                      : AppColors.ink,
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
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
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
                error: (_, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppAsyncErrorView(onRetry: _retry),
                ),
              ),
            ],
          ),
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
                  AppImages.placeCoverAsset(place.slug),
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
