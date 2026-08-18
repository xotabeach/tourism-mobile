import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/cache/api_cache.dart';
import 'package:tourism_mobile/core/cache/app_data_refresh.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/theme/app_colors.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/search/presentation/in_place_search.dart';
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
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'places-search');
  Timer? _searchDebounce;
  var _selectedChip = 'Все';
  var _searchQuery = '';
  var _searchFocused = false;
  String? _filterDifficulty;
  bool? _paidOnly;

  Future<void> _openFilters() async {
    final applied = await showModalBottomSheet<_PlaceFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlaceFiltersSheet(
        initialDifficulty: _filterDifficulty,
        initialPaidOnly: _paidOnly,
      ),
    );
    if (applied == null || !mounted) return;
    setState(() {
      _filterDifficulty = applied.difficulty;
      _paidOnly = applied.paidOnly;
    });
  }

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
    _searchFocus.addListener(() {
      if (mounted) {
        setState(() => _searchFocused = _searchFocus.hasFocus);
      }
    });
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

  List<PlaceSummary> _filtered(List<PlaceSummary> items) {
    var result = items;
    if (_selectedChip == 'Платно') {
      result = result.where((place) => place.isPaid).toList();
    } else if (_selectedChip != 'Все') {
      final needle = _selectedChip.toLowerCase();
      result = result
          .where(
            (place) => place.categories.any(
              (category) => category.name.toLowerCase().contains(needle),
            ),
          )
          .toList();
    }
    if (_filterDifficulty != null) {
      result = result
          .where((place) => place.difficulty == _filterDifficulty)
          .toList();
    }
    if (_paidOnly == true) {
      result = result.where((place) => place.isPaid).toList();
    } else if (_paidOnly == false) {
      result = result.where((place) => !place.isPaid).toList();
    }
    return result;
  }

  Future<void> _refresh() async {
    ref.read(apiCacheRegistryProvider).invalidateAll();
    await refreshAppData(ref, scope: AppDataRefreshScope.places);
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
    _searchFocus.dispose();
    _searchController.dispose();
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
    final placesAsync = ref.watch(placesListProvider);

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
                        hintText: 'Искать места',
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onSearchChanged: _onSearchChanged,
                        onSearchClear: () {
                          _searchDebounce?.cancel();
                          setState(() => _searchQuery = '');
                        },
                        onFilterTap: () => unawaited(_openFilters()),
                        filterApplied:
                            _filterDifficulty != null || _paidOnly != null,
                      ),
                      const SizedBox(height: 14),
                      if (!(_searchFocused || _searchQuery.isNotEmpty))
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _chips.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
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
              if (_searchFocused || _searchQuery.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                    child: InPlaceSearchBody(
                      query: _searchQuery,
                      scope: SearchScope.places,
                      onQueryFromHistory: (value) {
                        _searchController.text = value;
                        _onSearchChanged(value);
                      },
                    ),
                  ),
                )
              else
                placesAsync.when(
                  skipLoadingOnReload: true,
                  skipLoadingOnRefresh: true,
                  skipError: true,
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

class _PlaceCatalogCard extends ConsumerWidget {
  const _PlaceCatalogCard({required this.place});

  final PlaceSummary place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
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
                child: SizedBox(
                  width: 116,
                  height: 142,
                  child: AppImages.coverImage(
                    config: config,
                    coverImageUrl: place.coverImageUrl,
                    fallbackSeed: place.slug,
                  ),
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

/// Result of the place filters bottom sheet.
class _PlaceFilters {
  const _PlaceFilters({this.difficulty, this.paidOnly});

  final String? difficulty;
  final bool? paidOnly;
}

/// Filter bottom sheet: difficulty section + paid section + apply button.
class _PlaceFiltersSheet extends StatefulWidget {
  const _PlaceFiltersSheet({this.initialDifficulty, this.initialPaidOnly});

  final String? initialDifficulty;
  final bool? initialPaidOnly;

  @override
  State<_PlaceFiltersSheet> createState() => _PlaceFiltersSheetState();
}

class _PlaceFiltersSheetState extends State<_PlaceFiltersSheet> {
  static const _difficulties = <(String, String)>[
    ('easy', 'Лёгкая'),
    ('moderate', 'Средняя'),
    ('hard', 'Сложная'),
  ];

  String? _difficulty;
  bool? _paidOnly;

  @override
  void initState() {
    super.initState();
    _difficulty = widget.initialDifficulty;
    _paidOnly = widget.initialPaidOnly;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Material(
        color: AppColors.elevatedSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.controlSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Фильтры:',
                style: AppTypography.sectionTitle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              const Text('Сложность', style: AppTypography.settingsRowTitle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChoiceChip(
                    label: 'Любая',
                    selected: _difficulty == null,
                    onTap: () => setState(() => _difficulty = null),
                  ),
                  for (final (code, name) in _difficulties)
                    _FilterChoiceChip(
                      label: name,
                      selected: _difficulty == code,
                      onTap: () => setState(() => _difficulty = code),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Вход', style: AppTypography.settingsRowTitle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChoiceChip(
                    label: 'Любой',
                    selected: _paidOnly == null,
                    onTap: () => setState(() => _paidOnly = null),
                  ),
                  _FilterChoiceChip(
                    label: 'Бесплатно',
                    selected: _paidOnly == false,
                    onTap: () => setState(() => _paidOnly = false),
                  ),
                  _FilterChoiceChip(
                    label: 'Платно',
                    selected: _paidOnly == true,
                    onTap: () => setState(() => _paidOnly = true),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(
                    _PlaceFilters(difficulty: _difficulty, paidOnly: _paidOnly),
                  ),
                  child: const Text(
                    'Показать места',
                    style: TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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

class _FilterChoiceChip extends StatelessWidget {
  const _FilterChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentBlue : AppColors.controlSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
