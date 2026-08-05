import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_brand_bar.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/search/presentation/universal_search_panel.dart';
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
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'home-search');
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  var _selectedChip = 'Все';
  var _searchQuery = '';
  var _showPinnedBrand = false;
  var _showAllRoutes = false;
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
      return matchesChip &&
          (_searchQuery.isEmpty || haystack.contains(_searchQuery));
    }).toList();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim().toLowerCase());
    });
  }

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _dismissSearch() {
    _searchFocus.unfocus();
  }

  void _toggleAllRoutes() {
    _dismissSearch();
    setState(() => _showAllRoutes = !_showAllRoutes);
  }

  void _warmRouteCovers(
    BuildContext context,
    AppConfig config,
    List<RouteSummary> routes,
  ) {
    final pending = routes
        .take(3)
        .where((route) => _scheduledCoverWarmups.add(route.id))
        .toList(growable: false);
    if (pending.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final route in pending) {
        unawaited(
          precacheImage(
            AppImages.routeCoverProvider(
              config: config,
              coverImageUrl: route.coverImageUrl,
              fallbackSeed: route.slug,
              cacheWidth: 1080,
            ),
            context,
          ).catchError((_) {}),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    _searchFocus
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
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
    final routesAsync = ref.watch(homeRoutesProvider);
    final config = ref.watch(appConfigProvider);
    final name = (session.displayName?.trim().isNotEmpty ?? false)
        ? session.displayName!.trim()
        : 'путник';
    final topInset = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: AppColors.mist,
      child: Stack(
        fit: StackFit.expand,
        children: [
          routesAsync.when(
            data: (page) {
              final items = _filtered(page.items);
              final visibleItems = _showAllRoutes
                  ? items
                  : items.take(7).toList(growable: false);
              _warmRouteCovers(context, config, visibleItems);
              return ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  topInset + AppSpacing.lg,
                  AppSpacing.page,
                  AppSpacing.shellBottomContent,
                ),
                itemCount: 1 + (items.isEmpty ? 1 : visibleItems.length),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _HomeHeader(
                      name: name,
                      selectedChip: _selectedChip,
                      chips: _chips,
                      searchController: _searchController,
                      searchFocus: _searchFocus,
                      searchQuery: _searchQuery,
                      onSearchChanged: _onSearchChanged,
                      onSearchClear: _clearSearch,
                      onSearchDismiss: _dismissSearch,
                      onChipSelected: (chip) {
                        _dismissSearch();
                        setState(() => _selectedChip = chip);
                      },
                      showAllRoutes: _showAllRoutes,
                      onToggleAllRoutes: _toggleAllRoutes,
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
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => AppAsyncErrorView(
              onRetry: () => ref.invalidate(homeRoutesProvider),
            ),
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
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({
    required this.name,
    required this.selectedChip,
    required this.chips,
    required this.searchController,
    required this.searchFocus,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onSearchDismiss,
    required this.onChipSelected,
    required this.showAllRoutes,
    required this.onToggleAllRoutes,
  });

  final String name;
  final String selectedChip;
  final List<String> chips;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final VoidCallback onSearchDismiss;
  final ValueChanged<String> onChipSelected;
  final bool showAllRoutes;
  final VoidCallback onToggleAllRoutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(sessionProvider);
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
              semanticLabel: 'Уведомления',
              onPressed: () => unawaited(
                context.pushNamed(AppRouteNames.settingsNotificationsInbox),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSearchFilterRow(
          controller: searchController,
          focusNode: searchFocus,
          onSearchChanged: onSearchChanged,
          onSearchClear: onSearchClear,
          onSearchDismiss: onSearchDismiss,
          onFilterTap: () => context.pushNamed(AppRouteNames.places),
        ),
        // Keep results mounted while the query is active so a result tap can
        // navigate before focus loss removes the panel from the tree.
        if (searchQuery.trim().runes.length >= 2)
          UniversalSearchPanel(query: searchQuery),
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
        Row(
          children: [
            const Expanded(
              child: Text('Маршруты', style: AppTypography.sectionTitle),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleAllRoutes,
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                child: Text(
                  showAllRoutes ? 'Свернуть' : 'Листать все',
                  key: ValueKey(showAllRoutes),
                  style: AppTypography.sectionAction,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 17),
        AppFilterChipBar(
          labels: chips,
          selected: selectedChip,
          onSelected: onChipSelected,
        ),
        const SizedBox(height: 14),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          onTap: () => unawaited(
            context.pushNamed(
              AppRouteNames.userProfile,
              pathParameters: {'userId': traveler.id},
            ),
          ),
          child: Ink(
            height: 116,
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              boxShadow: AppShadows.tile,
            ),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 2),
                  ),
                  child: CircleAvatar(
                    backgroundColor: AppColors.mistDark,
                    backgroundImage: avatar,
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
