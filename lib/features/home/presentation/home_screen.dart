import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/cache/app_data_refresh.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_expert_style.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_brand_bar.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/core/performance/app_perf.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/home/presentation/all_list_screen.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/presentation/widgets/place_hero_card.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/search/presentation/in_place_search.dart';
import 'package:tourism_mobile/features/search/presentation/search_filters_sheet.dart';
import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';
import 'package:tourism_mobile/routing/app_router.dart';
import 'package:tourism_mobile/routing/shell/tab_scroll_to_top.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const routePath = '/';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _chips = ['Все', 'Море', 'Горы', 'Еда', 'Лес'];
  static const _pinnedBarThreshold = 48.0;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'home-search');
  Timer? _searchDebounce;
  var _selectedChip = 'Все';
  var _showPinnedBrand = false;
  var _mode = HomeListMode.routes;
  var _searchQuery = '';
  var _searchFocused = false;
  SearchFilters _searchFilters = const SearchFilters();
  final _scheduledCoverWarmups = <String>{};

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final offset = _scrollController.offset;
    syncTabScrolledDown(ref, 0, offset);
    final show = offset > _pinnedBarThreshold;
    if (show != _showPinnedBrand) {
      setState(() => _showPinnedBrand = show);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocus.addListener(_onSearchFocusChanged);
  }

  void _onSearchFocusChanged() {
    if (mounted) {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    }
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

  void _applyHistoryQuery(String value) {
    _searchDebounce?.cancel();
    _searchController
      ..text = value
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: value.length),
      );
    setState(() => _searchQuery = value.trim());
  }

  Future<void> _openFilters() async {
    final applied = await showSearchFiltersSheet(
      context,
      initial: _searchFilters,
    );
    if (applied == null || !mounted) {
      return;
    }
    setState(() => _searchFilters = applied);
  }

  List<RouteSummary> _filtered(List<RouteSummary> items) {
    return items.where((route) {
      final haystack =
          '${route.name} ${route.shortDescription ?? ''} '
                  '${route.authorLabel ?? ''} ${route.difficulty ?? ''} '
                  '${route.transportMode ?? ''}'
              .toLowerCase();
      final matchesChip = switch (_selectedChip.toLowerCase()) {
        'все' => true,
        'море' =>
          haystack.contains('берег') ||
              haystack.contains('ялт') ||
              haystack.contains('мор') ||
              haystack.contains('фиолент') ||
              haystack.contains('свет'),
        'горы' =>
          haystack.contains('гор') ||
              haystack.contains('бахчисар') ||
              haystack.contains('кале') ||
              haystack.contains('петри'),
        'еда' => haystack.contains('еда') || haystack.contains('кухн'),
        'лес' =>
          haystack.contains('лес') ||
              haystack.contains('троп') ||
              haystack.contains('сосны'),
        _ => true,
      };
      return matchesChip;
    }).toList();
  }

  void _warmRouteCovers(
    BuildContext context,
    AppConfig config,
    List<RouteSummary> routes,
  ) {
    final pending = routes
        .take(AppPerf.preferCheapEffects ? 5 : 7)
        .where((route) => _scheduledCoverWarmups.add(route.id))
        .toList(growable: false);
    if (pending.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final route in pending) {
        final provider = AppImages.routeCoverProvider(
          config: config,
          coverImageUrl: route.coverImageUrl,
          fallbackSeed: route.slug,
          cacheWidth: 1080,
        );
        if (provider == null) {
          continue;
        }
        unawaited(precacheImage(provider, context).catchError((_) {}));
      }
    });
  }

  void _seeAll() {
    unawaited(
      context.pushNamed(AppRouteNames.homeAllList, extra: _mode),
    );
  }

  /// Same header (toggle, search bar, chips) both modes and the loading
  /// skeleton render at index 0 — extracted so switching modes or waiting
  /// on a first fetch never has to rebuild this row differently.
  Widget _homeHeader({required String name, required bool searchActive}) {
    return _HomeHeader(
      name: name,
      mode: _mode,
      onModeChanged: (mode) => setState(() => _mode = mode),
      onSeeAll: _seeAll,
      selectedChip: _selectedChip,
      chips: _chips,
      onChipSelected: (chip) {
        setState(() => _selectedChip = chip);
      },
      searchController: _searchController,
      searchFocus: _searchFocus,
      searchActive: searchActive,
      filterApplied: _searchFilters.isActive,
      onSearchChanged: _onSearchChanged,
      onSearchClear: () {
        _searchDebounce?.cancel();
        setState(() => _searchQuery = '');
      },
      onFilterTap: () => unawaited(_openFilters()),
    );
  }

  /// Keeps the header (and therefore the Маршруты/Локации toggle) on screen
  /// while a mode's data is still loading, instead of replacing the whole
  /// page with a centered spinner — that used to read as the entire Home
  /// screen flashing blank on the first switch to Локации.
  Widget _buildLoadingList({
    required String name,
    required double topInset,
    required bool searchActive,
  }) {
    return _homeRefreshScroll(
      child: ListView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: _homeScrollPadding(topInset),
        children: [
          _homeHeader(name: name, searchActive: searchActive),
          const SizedBox(height: 16),
          const _HomeFeedSkeleton(),
        ],
      ),
    );
  }

  /// Error path keeps the header for the same reason the loading path does —
  /// a bare error view swapped for the whole page loses the toggle and the
  /// search bar, so the user cannot even switch modes to get out of it.
  Widget _buildErrorList({
    required String name,
    required double topInset,
    required bool searchActive,
  }) {
    return _homeRefreshScroll(
      child: ListView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: _homeScrollPadding(topInset),
        children: [
          _homeHeader(name: name, searchActive: searchActive),
          AppAsyncErrorView(
            onRetry: () =>
                unawaited(refreshAppData(ref, scope: AppDataRefreshScope.home)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutesList(
    BuildContext context, {
    required AppConfig config,
    required String name,
    required double topInset,
    required bool searchActive,
  }) {
    final routesAsync = ref.watch(homeRoutesProvider);
    return routesAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      data: (page) {
        final items = _filtered(page.items);
        final visibleItems = items.take(7).toList(growable: false);
        _warmRouteCovers(context, config, visibleItems);
        return _homeRefreshScroll(
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: _homeScrollPadding(topInset),
            itemCount: searchActive
                ? 2
                : 1 + (items.isEmpty ? 1 : visibleItems.length),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _homeHeader(name: name, searchActive: searchActive);
              }
              if (searchActive) {
                return InPlaceSearchBody(
                  query: _searchQuery,
                  filters: _searchFilters,
                  onQueryFromHistory: _applyHistoryQuery,
                );
              }
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(child: Text('Маршруты не найдены')),
                );
              }
              final route = visibleItems[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: RouteHeroCard(
                  route: route,
                  height: 304,
                  tags: index == 1
                      ? const ['Горы', 'С детьми', 'Пешком']
                      : const [],
                ),
              );
            },
          ),
        );
      },
      loading: () => _buildLoadingList(
        name: name,
        topInset: topInset,
        searchActive: searchActive,
      ),
      error: (_, _) => _buildErrorList(
        name: name,
        topInset: topInset,
        searchActive: searchActive,
      ),
    );
  }

  Widget _buildPlacesList(
    BuildContext context, {
    required String name,
    required double topInset,
    required bool searchActive,
  }) {
    final placesAsync = ref.watch(homePlacesProvider);
    return placesAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      data: (page) {
        // Same 7-card cap as routes — Локации shouldn't feel like a longer
        // list just because the /places page size differs from routes'.
        final items = page.items.take(7).toList(growable: false);
        return _homeRefreshScroll(
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: _homeScrollPadding(topInset),
            itemCount: searchActive ? 2 : 1 + (items.isEmpty ? 1 : items.length),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _homeHeader(name: name, searchActive: searchActive);
              }
              if (searchActive) {
                return InPlaceSearchBody(
                  query: _searchQuery,
                  filters: _searchFilters,
                  onQueryFromHistory: _applyHistoryQuery,
                );
              }
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(child: Text('Локации не найдены')),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PlaceHeroCard(place: items[index - 1]),
              );
            },
          ),
        );
      },
      loading: () => _buildLoadingList(
        name: name,
        topInset: topInset,
        searchActive: searchActive,
      ),
      error: (_, _) => _buildErrorList(
        name: name,
        topInset: topInset,
        searchActive: searchActive,
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchFocus
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
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
    final session = ref.watch(sessionProvider);
    final config = ref.watch(appConfigProvider);
    final name = (session.displayName?.trim().isNotEmpty ?? false)
        ? session.displayName!.trim()
        : 'путник';
    final topInset = MediaQuery.paddingOf(context).top;
    final searchActive = _searchActive;

    return ColoredBox(
      color: AppColors.mist,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _mode == HomeListMode.routes
              ? _buildRoutesList(
                  context,
                  config: config,
                  name: name,
                  topInset: topInset,
                  searchActive: searchActive,
                )
              : _buildPlacesList(
                  context,
                  name: name,
                  topInset: topInset,
                  searchActive: searchActive,
                ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              ignoring: !_showPinnedBrand,
              child: AnimatedSlide(
                duration: AppMotion.normal,
                curve: Curves.easeOutCubic,
                offset: _showPinnedBrand ? Offset.zero : const Offset(0, -1),
                child: AnimatedOpacity(
                  duration: AppMotion.normal,
                  opacity: _showPinnedBrand ? 1 : 0,
                  child: AppBrandBar(topInset: topInset),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _searchActive => _searchFocused || _searchQuery.isNotEmpty;

  EdgeInsets _homeScrollPadding(double topInset) {
    return EdgeInsets.fromLTRB(
      AppSpacing.page,
      topInset + AppSpacing.lg,
      AppSpacing.page,
      AppSpacing.shellBottomContent,
    );
  }

  Widget _homeRefreshScroll({required Widget child}) {
    return RefreshIndicator(
      onRefresh: () => refreshAppData(ref, scope: AppDataRefreshScope.home),
      child: child,
    );
  }

}

class _HomeFeedSkeleton extends StatelessWidget {
  const _HomeFeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return AppShimmer(
          child: Column(
            children: [
              AppSkeleton(width: width, height: 304),
              const SizedBox(height: 16),
              AppSkeleton(width: width, height: 304),
            ],
          ),
        );
      },
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({
    required this.name,
    required this.selectedChip,
    required this.chips,
    required this.onChipSelected,
    required this.mode,
    required this.onModeChanged,
    required this.onSeeAll,
    required this.searchController,
    required this.searchFocus,
    required this.searchActive,
    required this.filterApplied,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onFilterTap,
  });

  final String name;
  final String selectedChip;
  final List<String> chips;
  final ValueChanged<String> onChipSelected;
  final HomeListMode mode;
  final ValueChanged<HomeListMode> onModeChanged;
  final VoidCallback onSeeAll;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final bool searchActive;
  final bool filterApplied;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(sessionProvider);
    final unread = ref.watch(notificationsUnreadCountProvider);
    final avatar = AppImages.avatarProvider(
      config: config,
      avatarUrl: session.avatarUrl,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Открыть профиль',
                child: InkWell(
                  onTap: () => context.goNamed(AppRouteNames.profile),
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.mistDark,
                          backgroundImage: avatar,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Привет, $name!',
                                style: AppTypography.greeting,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Может пройдемся?',
                                style: AppTypography.greetingSubtitle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AppFlatIconButton(
              iconAsset: AppIconography.bell,
              semanticLabel: unread > 0
                  ? 'Уведомления, $unread новых'
                  : 'Уведомления',
              badgeCount: unread,
              onPressed: () => unawaited(
                context.pushNamed(AppRouteNames.settingsNotificationsInbox),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSearchFilterRow(
          hintText: 'Искать маршруты и места',
          controller: searchController,
          focusNode: searchFocus,
          filterApplied: filterApplied,
          onSearchChanged: onSearchChanged,
          onSearchClear: onSearchClear,
          onFilterTap: onFilterTap,
        ),
        if (searchActive)
          const SizedBox(height: 18)
        else ...[
          const SizedBox(height: AppSpacing.xl),
          const BuildRouteBanner(),
          const SizedBox(height: 25),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Топ путешественников',
                  style: AppTypography.sectionTitle,
                ),
              ),
              Semantics(
                button: true,
                label: 'Весь топ путешественников',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      context.pushNamed(AppRouteNames.travelersLeaderboard),
                  child: const Text(
                    'Весь топ',
                    style: AppTypography.sectionAction,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _TopTravelersRow(),
          const SizedBox(height: 30),
          AppSegmentedToggle(
            labels: const ['Маршруты', 'Локации'],
            selected: mode == HomeListMode.routes ? 'Маршруты' : 'Локации',
            onSelected: (label) => onModeChanged(
              label == 'Маршруты' ? HomeListMode.routes : HomeListMode.places,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  mode == HomeListMode.routes ? 'Маршруты' : 'Локации',
                  style: AppTypography.sectionTitle,
                ),
              ),
              Semantics(
                button: true,
                label: 'Смотреть все',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onSeeAll,
                  child: const Text(
                    'Смотреть все',
                    style: AppTypography.sectionAction,
                  ),
                ),
              ),
            ],
          ),
          if (mode == HomeListMode.routes) ...[
            const SizedBox(height: 17),
            AppFilterChipBar(
              labels: chips,
              selected: selectedChip,
              onSelected: onChipSelected,
            ),
          ],
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _TopTravelersRow extends ConsumerWidget {
  const _TopTravelersRow();

  static const _podiumColors = [
    Color(0xFFFFD400),
    Color(0xFFCFCFCF),
    Color(0xFFFFB35C),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTop = ref.watch(topTravelersProvider);
    final config = ref.watch(appConfigProvider);
    return asyncTop.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => const SizedBox(
        height: 116,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox(
        height: 116,
        child: Center(child: Text('Не удалось загрузить топ')),
      ),
      data: (travelers) {
        final items = travelers.take(3).toList(growable: false);
        if (items.isEmpty) {
          return const SizedBox(
            height: 116,
            child: Center(child: Text('Пока нет путешественников')),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _TopTravelerCard(
                  traveler: items[i],
                  place: items[i].leaderboardPlace > 0
                      ? items[i].leaderboardPlace
                      : i + 1,
                  ringColor:
                      _podiumColors[i.clamp(0, _podiumColors.length - 1)],
                  avatar: AppImages.imageProvider(
                    resolvedUrl: AppImages.resolveMediaUrl(
                      config,
                      items[i].avatarUrl,
                    ),
                    assetFallback: AppImages.travelerPortrait,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TopTravelerCard extends StatelessWidget {
  const _TopTravelerCard({
    required this.traveler,
    required this.place,
    required this.ringColor,
    required this.avatar,
  });

  final PublicUserProfile traveler;
  final int place;
  final Color ringColor;
  final ImageProvider avatar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${traveler.displayName}, место $place',
      child: DecoratedBox(
        key: ValueKey('top-traveler-shadow-$place'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.tile + 6),
          boxShadow: AppShadows.tile,
        ),
        child: AppExpertFrame(
          isExpert: traveler.isExpert,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              onTap: () => unawaited(
                context.pushNamed(
                  AppRouteNames.userProfile,
                  pathParameters: {'userId': traveler.id},
                ),
              ),
              child: SizedBox(
                height: 116,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
                  child: Column(
                    children: [
                      SizedBox.square(
                        dimension: 54,
                        child: AppExpertFrame(
                          isExpert: traveler.isExpert,
                          borderRadius: BorderRadius.circular(999),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: traveler.isExpert
                                  ? null
                                  : Border.all(color: ringColor, width: 2),
                            ),
                            child: CircleAvatar(
                              backgroundColor: AppColors.mistDark,
                              backgroundImage: avatar,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'ТОП $place',
                        style: AppTypography.chip.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatTravelPoints(traveler.travelPoints),
                        style: AppTypography.routeMetadata.copyWith(
                          color: AppColors.secondaryInk,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatTravelPoints(int points) {
  final raw = points.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write(' ');
    }
  }
  return '$buffer тп';
}
