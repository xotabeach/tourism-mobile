import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/native_liquid_glass.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  static const routePath = '/profile';

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  var _achievementPage = 0;
  var _publishedPage = 0;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: AppColors.pageSurface,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _ProfileHeader(
            profile: profile,
            topInset: topInset,
            onEdit: () => _snack('Редактирование профиля появится позже'),
            onMore: () => _snack('Настройки профиля появятся позже'),
          ),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RankCard(rank: profile.rank),
                  const SizedBox(height: AppSpacing.xl),
                  const Text('Достижения:', style: AppTypography.sectionTitle),
                  const SizedBox(height: AppSpacing.sm),
                  _AchievementsCarousel(
                    pages: profile.achievementPages,
                    pageIndex: _achievementPage,
                    onPageChanged: (index) {
                      setState(() => _achievementPage = index);
                    },
                    onAchievementTap: (achievement) {
                      _snack(achievement.title);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text('Избранное', style: AppTypography.sectionTitle),
                  const SizedBox(height: AppSpacing.sm),
                  const _FavoritesSummary(),
                  const SizedBox(height: AppSpacing.xl),
                  const Text(
                    'Опубликованные маршруты',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _PublishedRoutesCarousel(
                    routes: profile.publishedRoutes,
                    pageIndex: _publishedPage,
                    onPageChanged: (index) {
                      setState(() => _publishedPage = index);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoritesSummary extends ConsumerWidget {
  const _FavoritesSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final routeCount = favorites.routeIds.length;
    final placeCount = favorites.placeIds.length;
    final label = routeCount == 0 && placeCount == 0
        ? 'Пока пусто — свайпайте маршруты вправо'
        : 'Маршруты: $routeCount · Места: $placeCount';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pageSurface,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(label, style: AppTypography.routeMetadata),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.topInset,
    required this.onEdit,
    required this.onMore,
  });

  final ProfileSnapshot profile;
  final double topInset;
  final VoidCallback onEdit;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: topInset + 236,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(profile.coverImageAsset, fit: BoxFit.cover),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x00000000),
                    Color(0x99000000),
                  ],
                  stops: [0, 0.42, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.page,
            right: AppSpacing.page,
            bottom: 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundImage: AssetImage(profile.avatarImageAsset),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.greeting.copyWith(
                          color: Colors.white,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.rank.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.greetingSubtitle.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _HeaderActionButton(
                  tooltip: 'Редактировать профиль',
                  onTap: onEdit,
                  fillColor: Colors.white.withValues(alpha: 0.55),
                  iconColor: AppColors.primaryInk,
                  icon: Icons.edit_outlined,
                ),
                const SizedBox(width: 8),
                _HeaderActionButton(
                  tooltip: 'Ещё',
                  onTap: onMore,
                  fillColor: Colors.white.withValues(alpha: 0.4),
                  iconColor: AppColors.primaryInk,
                  icon: Icons.more_horiz_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.tooltip,
    required this.onTap,
    required this.fillColor,
    required this.iconColor,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Color fillColor;
  final Color iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 44,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              onTap();
            },
            customBorder: const CircleBorder(),
            child: AppAdaptiveGlassSurface(
              borderRadius: AppRadii.circle,
              shape: NativeLiquidGlassShape.circle,
              interactive: true,
              blur: 10,
              fillColor: fillColor,
              borderColor: Colors.white.withValues(alpha: 0.28),
              child: Icon(icon, size: 22, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.rank});

  final ProfileRank rank;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.tile,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Звание:',
                  style: AppTypography.greetingSubtitle.copyWith(
                    color: AppColors.primaryInk,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    rank.title,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.greeting.copyWith(fontSize: 17),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RankPill(
                  label: '${rank.progressPoints} / ${rank.nextRankPoints} тп',
                  filled: true,
                ),
                _RankPill(label: 'Топ ${rank.leaderboardPlace}', filled: false),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RankPill extends StatelessWidget {
  const _RankPill({required this.label, required this.filled});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: filled ? AppColors.primaryInk : AppColors.controlSurface,
        borderRadius: BorderRadius.circular(AppRadii.capsule),
      ),
      child: Text(
        label,
        style: AppTypography.chip.copyWith(
          fontSize: 13,
          color: filled ? Colors.white : AppColors.primaryInk,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AchievementsCarousel extends StatelessWidget {
  const _AchievementsCarousel({
    required this.pages,
    required this.pageIndex,
    required this.onPageChanged,
    required this.onAchievementTap,
  });

  final List<List<ProfileAchievement>> pages;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<ProfileAchievement> onAchievementTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 232,
          child: PageView.builder(
            itemCount: pages.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final items = pages[index];
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _AchievementTile(
                      achievement: items[i],
                      onTap: () => onAchievementTap(items[i]),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _PageDots(count: pages.length, index: pageIndex),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.onTap});

  final ProfileAchievement achievement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressableScale(
      borderRadius: AppRadii.card,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: AppShadows.tile,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.focus,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.chip.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      achievement.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.routeMetadata.copyWith(
                        color: AppColors.secondaryInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishedRoutesCarousel extends StatelessWidget {
  const _PublishedRoutesCarousel({
    required this.routes,
    required this.pageIndex,
    required this.onPageChanged,
  });

  final List<RouteSummary> routes;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 304,
          child: PageView.builder(
            itemCount: routes.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: RouteHeroCard(
                  route: routes[index],
                  height: 304,
                  tags: const [],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _PageDots(count: routes.length, index: pageIndex),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index
                  ? AppColors.primaryInk
                  : AppColors.controlSurface,
            ),
          ),
        ],
      ],
    );
  }
}
