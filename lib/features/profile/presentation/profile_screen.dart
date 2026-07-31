import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/native_liquid_glass.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/routing/app_router.dart';
import 'package:tourism_mobile/routing/shell/tab_scroll_to_top.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId});

  static const routePath = '/profile';
  static const userRoutePath = 'users/:userId';

  /// When set and different from the signed-in user, shows a view-only profile.
  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _scrollController = ScrollController();
  var _achievementPage = 0;
  var _publishedPage = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(tabScrollToTopProvider(4), (previous, next) {
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
    final viewingOther =
        widget.userId != null &&
        widget.userId!.isNotEmpty &&
        widget.userId != session.userId;

    if (viewingOther) {
      final asyncProfile = ref.watch(publicProfileProvider(widget.userId!));
      return asyncProfile.when(
        data: (profile) => _buildBody(
          profile: profile,
          topInset: MediaQuery.paddingOf(context).top,
          isOwn: false,
        ),
        loading: () => const ColoredBox(
          color: AppColors.pageSurface,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => ColoredBox(
          color: AppColors.pageSurface,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Не удалось загрузить профиль',
                    style: AppTypography.sectionTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: AppTypography.routeMetadata,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(publicProfileProvider(widget.userId!)),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final profile = ref.watch(profileProvider);
    final sessionUserId = session.userId;
    final ProfileSnapshot effective;
    if (sessionUserId != null && sessionUserId.isNotEmpty) {
      effective = ref
          .watch(publicProfileProvider(sessionUserId))
          .maybeWhen(data: (value) => value, orElse: () => profile);
    } else {
      effective = profile;
    }
    return _buildBody(
      profile: effective,
      topInset: MediaQuery.paddingOf(context).top,
      isOwn: true,
    );
  }

  Widget _buildBody({
    required ProfileSnapshot profile,
    required double topInset,
    required bool isOwn,
  }) {
    // Same chrome for own and other profiles. Permissions only gate edit
    // entry points (settings); rank/achievements stay visible (mock until
    // Phase 14 durable progress API).
    return ColoredBox(
      color: AppColors.pageSurface,
      child: ListView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _ProfileHeader(
            profile: profile,
            topInset: topInset,
            onMore: isOwn
                ? () => context.pushNamed(AppRouteNames.settings)
                : null,
            onBack: isOwn ? null : () => context.pop(),
          ),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RankCard(rank: profile.rank),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Достижения:',
                        style: AppTypography.sectionTitle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
                // Full-bleed PageView so adjacent pages clip at the screen
                // edge, not inside the page inset.
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Опубликованные маршруты',
                        style: AppTypography.sectionTitle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (profile.publishedRoutes.isEmpty)
                        Text(
                          isOwn
                              ? 'Пока нет опубликованных маршрутов'
                              : 'У путешественника пока нет маршрутов',
                          style: AppTypography.routeMetadata,
                        ),
                    ],
                  ),
                ),
                if (profile.publishedRoutes.isNotEmpty)
                  _PublishedRoutesCarousel(
                    routes: profile.publishedRoutes,
                    pageIndex: _publishedPage,
                    authorAvatarUrl: profile.avatarImageUrl,
                    onPageChanged: (index) {
                      setState(() => _publishedPage = index);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.topInset,
    this.onMore,
    this.onBack,
  });

  final ProfileSnapshot profile;
  final double topInset;
  final VoidCallback? onMore;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final cover = AppImages.imageProvider(
      resolvedUrl: profile.coverImageUrl,
      assetFallback: profile.coverImageAsset,
    );
    final avatar = AppImages.imageProvider(
      resolvedUrl: profile.avatarImageUrl,
      assetFallback: profile.avatarImageAsset,
    );

    return SizedBox(
      height: topInset + 236,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image(image: cover, fit: BoxFit.cover),
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
                  child: CircleAvatar(radius: 32, backgroundImage: avatar),
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
                          fontWeight: FontWeight.w600,
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
                if (onBack != null)
                  _HeaderActionButton(
                    tooltip: 'Назад',
                    onTap: onBack!,
                    fillColor: Colors.black.withValues(alpha: 0.35),
                    iconColor: Colors.white,
                    icon: Icons.arrow_back_ios_new_rounded,
                  )
                else if (onMore != null)
                  _HeaderActionButton(
                    tooltip: 'Настройки',
                    onTap: onMore!,
                    fillColor: Colors.black.withValues(alpha: 0.35),
                    iconColor: Colors.white,
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
    final progress = rank.nextRankPoints <= 0
        ? 0.0
        : (rank.progressPoints / rank.nextRankPoints).clamp(0.0, 1.0);

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
                    style: AppTypography.greeting.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.capsule),
                    child: SizedBox(
                      height: 34,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: Color(0xFFE8E8E8)),
                          FractionallySizedBox(
                            widthFactor: progress,
                            alignment: Alignment.centerLeft,
                            child: const ColoredBox(
                              color: AppColors.primaryInk,
                            ),
                          ),
                          Center(
                            child: Text(
                              '${rank.progressPoints} / ${rank.nextRankPoints} тп',
                              style: AppTypography.chip.copyWith(
                                fontSize: 13,
                                color: progress > 0.45
                                    ? Colors.white
                                    : AppColors.primaryInk,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.controlSurface,
                    borderRadius: BorderRadius.circular(AppRadii.capsule),
                  ),
                  child: Text(
                    'Топ ${rank.leaderboardPlace}',
                    style: AppTypography.chip.copyWith(
                      fontSize: 13,
                      color: AppColors.primaryInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
            padEnds: false,
            itemBuilder: (context, index) {
              final items = pages[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _AchievementTile(
                        achievement: items[i],
                        onTap: () => onAchievementTap(items[i]),
                      ),
                    ],
                  ],
                ),
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
    return SizedBox(
      width: double.infinity,
      child: AppPressableScale(
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
                    color: AppColors.accentBlue,
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
      ),
    );
  }
}

class _PublishedRoutesCarousel extends StatelessWidget {
  const _PublishedRoutesCarousel({
    required this.routes,
    required this.pageIndex,
    required this.onPageChanged,
    this.authorAvatarUrl,
  });

  final List<RouteSummary> routes;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;
  final String? authorAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 304,
          child: PageView.builder(
            itemCount: routes.length,
            onPageChanged: onPageChanged,
            padEnds: false,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: RouteHeroCard(
                  route: routes[index],
                  height: 304,
                  tags: const [],
                  authorAvatarUrl: authorAvatarUrl,
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
            width: i == index ? 9 : 7,
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
