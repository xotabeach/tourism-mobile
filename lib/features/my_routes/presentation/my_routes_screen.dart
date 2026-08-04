import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/routing/shell/tab_scroll_to_top.dart';

enum MyRoutesTab { favorites, subscriptions, history }

/// 4-й раздел nav bar: избранное / подписки / история.
class MyRoutesScreen extends ConsumerStatefulWidget {
  const MyRoutesScreen({super.key});

  static const routePath = '/my-routes';

  @override
  ConsumerState<MyRoutesScreen> createState() => _MyRoutesScreenState();
}

class _MyRoutesScreenState extends ConsumerState<MyRoutesScreen> {
  static const _branchIndex = 3;

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'my-routes-search');
  final _scrollController = ScrollController();
  MyRoutesTab _tab = MyRoutesTab.favorites;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(tabScrollToTopProvider(_branchIndex), (previous, next) {
      if (!_scrollController.hasClients) {
        return;
      }
      unawaited(
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        ),
      );
    });

    final top = MediaQuery.paddingOf(context).top;
    final favorites = ref.watch(favoritesProvider);
    final routesAsync = ref.watch(routesListProvider);

    return ColoredBox(
      color: AppColors.pageSurface,
      child: routesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Не удалось загрузить: $error')),
        data: (page) {
          final routes = page.items;
          final favoriteRoutes = routes
              .where((r) => favorites.routeIds.contains(r.id))
              .toList();
          final historyRoutes = routes.take(6).toList();
          final filtered = _filterRoutes(switch (_tab) {
            MyRoutesTab.favorites => favoriteRoutes,
            MyRoutesTab.history => historyRoutes,
            MyRoutesTab.subscriptions => const <RouteSummary>[],
          });

          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, top + 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Мои маршруты:',
                        style: AppTypography.sectionTitle.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppSearchFilterRow(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        hintText: 'Маршрут или профиль',
                        onSearchChanged: (value) =>
                            setState(() => _query = value.trim()),
                        onSearchClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        onSearchDismiss: _searchFocus.unfocus,
                        onFilterTap: () {},
                      ),
                      const SizedBox(height: 14),
                      _TabRow(
                        selected: _tab,
                        onChanged: (tab) => setState(() => _tab = tab),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              if (_tab == MyRoutesTab.subscriptions)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                  sliver: SliverList.separated(
                    itemCount: _mockSubscriptions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _mockSubscriptions[index];
                      return _SubscriptionTile(item: item);
                    },
                  ),
                )
              else if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Пока пусто',
                      style: AppTypography.settingsRowSubtitle,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => SizedBox(
                      height: _tab == MyRoutesTab.favorites ? 4 : 16,
                    ),
                    itemBuilder: (context, index) {
                      final route = filtered[index];
                      if (_tab == MyRoutesTab.favorites) {
                        return _FavoriteRouteTile(
                          key: ValueKey('favorite-route-${route.id}'),
                          route: route,
                          onRemove: () => _removeFavorite(route),
                        );
                      }
                      return RouteHeroCard(route: route, height: 295);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<RouteSummary> _filterRoutes(List<RouteSummary> source) {
    if (_query.isEmpty) {
      return source;
    }
    final q = _query.toLowerCase();
    return source
        .where(
          (r) =>
              r.name.toLowerCase().contains(q) ||
              (r.authorLabel?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  Future<void> _removeFavorite(RouteSummary route) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(favoritesProvider.notifier).removeRoute(route.id);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 112),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.field),
            ),
            content: Text(
              '«${route.name}» удалён из избранного',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            action: SnackBarAction(
              label: 'Вернуть',
              onPressed: () => unawaited(_restoreFavorite(route.id)),
            ),
          ),
        );
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось обновить избранное')),
      );
    }
  }

  Future<void> _restoreFavorite(String routeId) async {
    try {
      await ref.read(favoritesProvider.notifier).addRoute(routeId);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось вернуть маршрут')),
      );
    }
  }
}

class _FavoriteRouteTile extends StatefulWidget {
  const _FavoriteRouteTile({
    required this.route,
    required this.onRemove,
    super.key,
  });

  final RouteSummary route;
  final Future<void> Function() onRemove;

  @override
  State<_FavoriteRouteTile> createState() => _FavoriteRouteTileState();
}

class _FavoriteRouteTileState extends State<_FavoriteRouteTile> {
  bool _leaving = false;
  bool _collapsed = false;
  double _swipeProgress = 0;

  Duration get _exitDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 300);

  Duration get _collapseDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 220);

  Future<void> _animateRemove() async {
    if (_leaving) return;
    unawaited(AppHaptics.mediumImpact());
    setState(() => _leaving = true);
    await Future<void>.delayed(_exitDuration);
    if (!mounted) return;
    setState(() => _collapsed = true);
    await Future<void>.delayed(_collapseDuration);
    if (!mounted) return;
    await widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.route.name}, маршрут в избранном',
      hint: 'Смахните влево, чтобы убрать из избранного',
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Удалить из избранного'): () {
          unawaited(_animateRemove());
        },
      },
      child: AnimatedSize(
        duration: _collapseDuration,
        curve: AppMotion.emphasizedCurve,
        alignment: Alignment.topCenter,
        child: _collapsed
            ? const SizedBox(width: double.infinity)
            : AnimatedSlide(
                duration: _exitDuration,
                curve: AppMotion.liquidOut,
                offset: _leaving ? const Offset(-1.08, 0) : Offset.zero,
                child: AnimatedScale(
                  duration: _exitDuration,
                  curve: AppMotion.emphasizedCurve,
                  scale: _leaving ? 0.96 : 1,
                  alignment: Alignment.centerLeft,
                  child: AnimatedOpacity(
                    duration: _exitDuration,
                    curve: const Interval(0, 0.72, curve: Curves.easeOut),
                    opacity: _leaving ? 0 : 1,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _FavoriteRemoveBackground(
                            progress: _swipeProgress,
                          ),
                        ),
                        Dismissible(
                          key: ValueKey('favorite-dismiss-${widget.route.id}'),
                          direction: DismissDirection.endToStart,
                          dismissThresholds: const {
                            DismissDirection.endToStart: 0.28,
                          },
                          movementDuration: AppMotion.emphasized,
                          resizeDuration: _collapseDuration,
                          onUpdate: (details) {
                            final progress = details.progress.clamp(0.0, 1.0);
                            if ((progress - _swipeProgress).abs() < 0.01) {
                              return;
                            }
                            setState(() => _swipeProgress = progress);
                          },
                          confirmDismiss: (_) async {
                            unawaited(AppHaptics.mediumImpact());
                            return true;
                          },
                          onDismissed: (_) => unawaited(widget.onRemove()),
                          child: SizedBox(
                            height: 307,
                            child: Center(
                              child: RouteHeroCard(
                                route: widget.route,
                                height: 295,
                                onFavoriteToggle: _animateRemove,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _FavoriteRemoveBackground extends StatelessWidget {
  const _FavoriteRemoveBackground({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final reveal = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card + 6),
      child: ColoredBox(
        key: const ValueKey('favorite-remove-background'),
        color: Color.lerp(
          Colors.transparent,
          AppColors.negativeSwipeTint,
          reveal,
        )!,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxHeight < 72 || constraints.maxWidth < 100) {
              return const SizedBox.shrink();
            }
            return Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Transform.scale(
                  scale: 0.72 + 0.28 * reveal,
                  child: Opacity(
                    opacity: 0.45 + 0.55 * reveal,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.heart_broken_rounded,
                          color: Colors.white,
                          size: 29,
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Убрать',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Rubik',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.selected, required this.onChanged});

  final MyRoutesTab selected;
  final ValueChanged<MyRoutesTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tab in MyRoutesTab.values) ...[
          if (tab != MyRoutesTab.values.first) const SizedBox(width: 8),
          Expanded(
            child: _TabChip(
              label: switch (tab) {
                MyRoutesTab.favorites => 'Избранное',
                MyRoutesTab.subscriptions => 'Подписки',
                MyRoutesTab.history => 'История',
              },
              selected: selected == tab,
              onTap: () => onChanged(tab),
            ),
          ),
        ],
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
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
      color: selected ? AppColors.accentBlue : AppColors.elevatedSurface,
      borderRadius: BorderRadius.circular(AppRadii.capsule),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.capsule),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.capsule),
            border: selected ? null : Border.all(color: AppColors.hairline),
          ),
          child: Text(
            label,
            style: AppTypography.settingsRowTitle.copyWith(
              fontSize: 14,
              color: selected ? Colors.white : AppColors.primaryInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubscriptionItem {
  const _SubscriptionItem({
    required this.name,
    required this.rank,
    required this.routesLabel,
  });

  final String name;
  final String rank;
  final String routesLabel;
}

const _mockSubscriptions = [
  _SubscriptionItem(
    name: 'Никита',
    rank: 'Продвинутый пешеход',
    routesLabel: '12 маршрутов',
  ),
  _SubscriptionItem(
    name: 'Мария',
    rank: 'Исследователь',
    routesLabel: '8 маршрутов',
  ),
  _SubscriptionItem(name: 'Артём', rank: 'Новичок', routesLabel: '3 маршрута'),
];

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({required this.item});

  final _SubscriptionItem item;

  @override
  Widget build(BuildContext context) {
    final initial = item.name.isEmpty ? '?' : item.name[0];
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.settingsTile),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.controlSurface,
            child: Text(
              initial,
              style: AppTypography.sectionTitle.copyWith(fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTypography.settingsRowTitle),
                const SizedBox(height: 2),
                Text(item.rank, style: AppTypography.settingsRowSubtitle),
                Text(
                  item.routesLabel,
                  style: AppTypography.settingsRowSubtitle.copyWith(
                    color: AppColors.accentBlue,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.secondaryInk,
          ),
        ],
      ),
    );
  }
}
