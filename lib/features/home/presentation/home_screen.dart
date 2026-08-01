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
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
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
  var _selectedChip = 'Все';
  var _searchQuery = '';
  var _showPinnedBrand = false;

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
    setState(() => _searchQuery = value.trim().toLowerCase());
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _dismissSearch() {
    _searchFocus.unfocus();
  }

  @override
  void dispose() {
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
    final session = ref.watch(sessionProvider);
    final routesAsync = ref.watch(routesListProvider);
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
                itemCount: 1 + (items.isEmpty ? 1 : items.length),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _HomeHeader(
                      name: name,
                      selectedChip: _selectedChip,
                      chips: _chips,
                      searchController: _searchController,
                      searchFocus: _searchFocus,
                      onSearchChanged: _onSearchChanged,
                      onSearchClear: _clearSearch,
                      onSearchDismiss: _dismissSearch,
                      onChipSelected: (chip) {
                        _dismissSearch();
                        setState(() => _selectedChip = chip);
                      },
                    );
                  }
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: Text('Маршруты не найдены')),
                    );
                  }
                  final route = items[index - 1];
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
              onRetry: () => ref.invalidate(routesListProvider),
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
                  child: _HomePinnedBrandBar(topInset: topInset),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomePinnedBrandBar extends StatelessWidget {
  const _HomePinnedBrandBar({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pageSurface.withValues(alpha: 0.94),
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.mistDark.withValues(alpha: 0.55)),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page,
            topInset + 8,
            AppSpacing.page,
            10,
          ),
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(
                'КРЫМТРИП',
                style: AppTypography.settingsBrand.copyWith(
                  color: AppColors.settingsBrand,
                ),
              ),
            ),
          ),
        ),
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
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onSearchDismiss,
    required this.onChipSelected,
  });

  final String name;
  final String selectedChip;
  final List<String> chips;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final VoidCallback onSearchDismiss;
  final ValueChanged<String> onChipSelected;

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
              onPressed: () {},
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
          onFilterTap: () => context.goNamed(AppRouteNames.places),
        ),
        const SizedBox(height: AppSpacing.xl),
        const BuildRouteBanner(),
        const SizedBox(height: 25),
        const Row(
          children: [
            Expanded(
              child: Text(
                'Топ путешественников',
                style: AppTypography.sectionTitle,
              ),
            ),
            Text('Весь топ', style: AppTypography.sectionAction),
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
              onTap: () => context.goNamed(AppRouteNames.routes),
              child: const Text(
                'Листать все',
                style: AppTypography.sectionAction,
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
                      border: Border.all(color: _travelers[i].$3, width: 2),
                    ),
                    child: const CircleAvatar(
                      backgroundImage: AssetImage(AppImages.travelerPortrait),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _travelers[i].$1,
                    style: AppTypography.chip.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _travelers[i].$2,
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
        ],
      ],
    );
  }
}
