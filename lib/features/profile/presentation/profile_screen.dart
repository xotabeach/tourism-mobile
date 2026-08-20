import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/cache/app_data_refresh.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_expert_style.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/app_favorite_icon.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/core/design/components/collapsing_hero_header.dart';
import 'package:tourism_mobile/core/design/components/native_liquid_glass.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/routing/app_router.dart';
import 'package:tourism_mobile/routing/shell/tab_scroll_to_top.dart';

String compactCount(int value) {
  if (value >= 1000) {
    final thousands = value / 1000;
    final text = thousands == thousands.roundToDouble()
        ? thousands.toStringAsFixed(0)
        : thousands.toStringAsFixed(1);
    return '$text тыс.';
  }
  return '$value';
}

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
  var _pullDownOffset = 0.0;

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final offset = _scrollController.offset;
    syncTabScrolledDown(ref, 4, offset);
    final nextPull = (-offset).clamp(0.0, 140.0);
    if ((nextPull - _pullDownOffset).abs() > 0.5 && mounted) {
      setState(() => _pullDownOffset = nextPull);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
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
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        skipError: true,
        data: (profile) => _buildBody(
          profile: profile,
          topInset: MediaQuery.paddingOf(context).top,
          isOwn: false,
          onRefresh: () => refreshAppData(
            ref,
            scope: AppDataRefreshScope.profile,
            profileUserId: widget.userId,
          ),
        ),
        loading: () =>
            _ProfileLoadingView(topInset: MediaQuery.paddingOf(context).top),
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
      final asyncProfile = ref.watch(publicProfileProvider(sessionUserId));
      if (asyncProfile.isLoading && !asyncProfile.hasValue) {
        return _ProfileLoadingView(topInset: MediaQuery.paddingOf(context).top);
      }
      effective = asyncProfile.valueOrNull ?? profile;
    } else {
      effective = profile;
    }
    return _buildBody(
      profile: effective,
      topInset: MediaQuery.paddingOf(context).top,
      isOwn: true,
      onRefresh: () => refreshAppData(ref, scope: AppDataRefreshScope.profile),
    );
  }

  Widget _buildBody({
    required ProfileSnapshot profile,
    required double topInset,
    required bool isOwn,
    Future<void> Function()? onRefresh,
  }) {
    // Same chrome for own and other profiles. Permissions only gate edit
    // entry points (settings); rank/achievements stay visible (mock until
    // Phase 14 durable progress API).
    final onMore = isOwn
        ? () => context.pushNamed(AppRouteNames.settings)
        : null;
    final onLike = isOwn
        ? null
        : () {
            final userId = widget.userId;
            if (userId == null || userId.isEmpty) {
              return;
            }
            unawaited(
              ref.read(profileLikeControllerProvider.notifier).toggle(userId),
            );
          };

    return ColoredBox(
      color: AppColors.pageSurface,
      child: RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _ProfileCollapsingHeader(
              profile: profile,
              topInset: topInset,
              isOwn: isOwn,
              onMore: onMore,
              onLike: onLike,
              likedByMe: profile.likedByMe,
              isExpert: profile.isExpert,
              pullDownOffset: _pullDownOffset,
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.xl,
                      AppSpacing.page,
                      0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Достижения:',
                          style: AppTypography.sectionTitle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Все достижения',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadii.chip),
                            onTap: () =>
                                context.pushNamed(AppRouteNames.achievements),
                            child: const Padding(
                              padding: EdgeInsets.fromLTRB(10, 6, 2, 6),
                              child: Row(
                                children: [
                                  Text(
                                    'Все',
                                    style: AppTypography.sectionAction,
                                  ),
                                  SizedBox(width: 2),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: AppColors.secondaryInk,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _AchievementsCarousel(
                    pages: pageUnlockedAchievements([
                      for (final page in profile.achievementPages) ...page,
                    ]),
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
                          isOwn ? 'Мои маршруты' : 'Опубликованные маршруты',
                          style: AppTypography.sectionTitle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (profile.publishedRoutes.isEmpty)
                          Text(
                            isOwn
                                ? 'У вас пока нет своих маршрутов'
                                : 'У путешественника пока нет маршрутов',
                            style: AppTypography.routeMetadata,
                          ),
                      ],
                    ),
                  ),
                  if (profile.publishedRoutes.isNotEmpty)
                    _PublishedRoutesCarousel(
                      routes: profile.publishedRoutes,
                      authorIsExpert: profile.isExpert,
                      showStatuses: isOwn,
                      pageIndex: _publishedPage,
                      authorAvatarUrl: profile.avatarImageUrl,
                      onPageChanged: (index) {
                        setState(() => _publishedPage = index);
                      },
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  const SizedBox(height: AppSpacing.shellBottomContent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pageSurface,
      child: AppShimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: topInset + _ProfileCollapsingHeader.coverBody,
                child: const Stack(
                  children: [
                    Positioned.fill(
                      child: AppSkeleton(
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 28,
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.page,
                      bottom: 16,
                      child: Row(
                        children: [
                          AppSkeleton(
                            width: 68,
                            height: 68,
                            shape: BoxShape.circle,
                          ),
                          SizedBox(width: 12),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppSkeleton(
                                width: 154,
                                height: 22,
                                borderRadius: 8,
                              ),
                              SizedBox(height: 8),
                              AppSkeleton(
                                width: 126,
                                height: 14,
                                borderRadius: 7,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height:
                    _ProfileCollapsingHeader.rankCardHeight -
                    _ProfileCollapsingHeader.rankOverlap,
                child: OverflowBox(
                  alignment: Alignment.bottomCenter,
                  minHeight: _ProfileCollapsingHeader.rankCardHeight,
                  maxHeight: _ProfileCollapsingHeader.rankCardHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                    child: AppSkeleton(
                      width: double.infinity,
                      height: _ProfileCollapsingHeader.rankCardHeight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: AppSkeleton(width: 164, height: 24, borderRadius: 8),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < 3; i++) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  child: AppSkeleton(width: double.infinity, height: 64),
                ),
                if (i < 2) const SizedBox(height: 8),
              ],
              const SizedBox(height: AppSpacing.xl),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: AppSkeleton(width: 132, height: 24, borderRadius: 8),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: AppSkeleton(width: double.infinity, height: 304),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCover extends StatelessWidget {
  const _ProfileCover({required this.profile, required this.isExpert});

  final ProfileSnapshot profile;
  final bool isExpert;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('profile-cover'),
      decoration: BoxDecoration(
        gradient: isExpert ? AppExpertStyle.gradient : null,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: isExpert ? 2 : 0),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(28),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(profile.coverImageAsset, fit: BoxFit.cover),
              if (profile.coverImageUrl != null &&
                  profile.coverImageUrl!.isNotEmpty)
                Image(
                  image: AppImages.imageProvider(
                    resolvedUrl: profile.coverImageUrl,
                    assetFallback: profile.coverImageAsset,
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) =>
                      Image.asset(profile.coverImageAsset, fit: BoxFit.cover),
                ),
              const DecoratedBox(
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCollapsingHeader extends StatelessWidget {
  const _ProfileCollapsingHeader({
    required this.profile,
    required this.topInset,
    required this.isOwn,
    this.onMore,
    this.onLike,
    this.likedByMe = false,
    this.isExpert = false,
    this.pullDownOffset = 0,
  });

  /// Geometry measured from the 393 logical-pixel Figma export.
  static const double coverBody = 174;
  static const double rankCardHeight = 190;
  static const double rankOverlap = 26;

  static const double identityAboveRank = 16;
  static const double collapsedBar = 56;

  final ProfileSnapshot profile;
  final double topInset;
  final bool isOwn;
  final VoidCallback? onMore;
  final VoidCallback? onLike;
  final bool likedByMe;
  final bool isExpert;
  final double pullDownOffset;

  @override
  Widget build(BuildContext context) {
    final avatarAsset = AssetImage(profile.avatarImageAsset);
    final avatarNetwork =
        profile.avatarImageUrl != null &&
            profile.avatarImageUrl!.isNotEmpty &&
            !AppImages.isAssetPath(profile.avatarImageUrl)
        ? AppImages.imageProvider(
            resolvedUrl: profile.avatarImageUrl,
            assetFallback: profile.avatarImageAsset,
          )
        : null;
    final coverHeight = topInset + coverBody;
    final expandedHeight = coverHeight + rankCardHeight - rankOverlap;

    return CollapsingHeroSliver(
      // Keep the collapsed bar pinned; the full hero stays in one sliver.
      pinned: true,
      parallaxFactor: 0.18,
      clipBehavior: Clip.none,
      expandedHeight: expandedHeight,
      collapsedHeight: topInset + collapsedBar,
      collapsedColor: AppColors.pageSurface,
      background: Stack(
        fit: StackFit.expand,
        children: [
          // Align cover to the top so parallax does not expose empty bands.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: coverHeight,
            child: _ProfileCover(profile: profile, isExpert: isExpert),
          ),
        ],
      ),
      builder: (context, t, shrinkOffset, currentExtent) {
        final expandedVis = CollapseProgress.fadeOut(t, start: 0.0, end: 0.5);
        final collapsedVis = CollapseProgress.fadeIn(t, start: 0.45, end: 0.95);
        final action = onLike != null
            ? _HeaderActionButton(
                tooltip: likedByMe ? 'Убрать лайк' : 'Лайк профиля',
                onTap: onLike!,
                fillColor: Colors.black.withValues(alpha: 0.35),
                iconColor: Colors.white,
                iconWidget: AppFavoriteIcon(selected: likedByMe, size: 22),
              )
            : onMore != null
            ? _HeaderActionButton(
                tooltip: 'Настройки',
                onTap: onMore!,
                fillColor: Colors.black.withValues(alpha: 0.35),
                iconColor: Colors.white,
                icon: Icons.more_horiz_rounded,
              )
            : null;
        final collapsedAction = onLike != null
            ? CollapsingHeroAction(
                semanticLabel: likedByMe ? 'Убрать лайк' : 'Лайк профиля',
                iconWidget: AppFavoriteIcon(
                  selected: likedByMe,
                  size: 22,
                  color: AppColors.primaryInk,
                ),
                onPhoto: false,
                onPressed: onLike!,
              )
            : onMore != null
            ? CollapsingHeroAction(
                semanticLabel: 'Настройки',
                icon: Icons.more_horiz_rounded,
                onPhoto: false,
                onPressed: onMore!,
              )
            : null;

        return Stack(
          fit: StackFit.expand,
          children: [
            CollapseLayer(
              key: const ValueKey('profile-pull-group'),
              visibility: expandedVis,
              scale: false,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: rankCardHeight - rankOverlap,
                    child: Transform.translate(
                      offset: Offset(0, pullDownOffset),
                      child: const ColoredBox(color: AppColors.pageSurface),
                    ),
                  ),
                  // Identity remains fixed to the cover during pull-to-refresh.
                  Positioned(
                    key: const ValueKey('profile-fixed-identity'),
                    left: AppSpacing.page,
                    right: AppSpacing.page,
                    bottom: rankCardHeight + identityAboveRank,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            gradient: isExpert
                                ? AppExpertStyle.gradient
                                : const LinearGradient(
                                    colors: [Colors.white, Colors.white],
                                  ),
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundImage: avatarAsset,
                            foregroundImage: avatarNetwork,
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
                        if (action != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          action,
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.page,
                    right: AppSpacing.page,
                    bottom: 0,
                    height: rankCardHeight,
                    child: Transform.translate(
                      key: const ValueKey('profile-pull-rank'),
                      offset: Offset(0, pullDownOffset),
                      child: _RankCard(
                        rank: profile.rank,
                        followersCount: profile.followersCount,
                        followingCount: profile.followingCount,
                        showFollowing: isOwn,
                        isExpert: isExpert,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            CollapseLayer(
              visibility: collapsedVis,
              scale: false,
              child: Padding(
                padding: EdgeInsets.only(top: topInset),
                child: SizedBox(
                  height: collapsedBar,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: avatarAsset,
                          foregroundImage: avatarNetwork,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            profile.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.greeting.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryInk,
                            ),
                          ),
                        ),
                        ?collapsedAction,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.tooltip,
    required this.onTap,
    required this.fillColor,
    required this.iconColor,
    this.icon,
    this.iconWidget,
  }) : assert((icon == null) != (iconWidget == null));

  final String tooltip;
  final VoidCallback onTap;
  final Color fillColor;
  final Color iconColor;
  final IconData? icon;
  final Widget? iconWidget;

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
              unawaited(AppHaptics.selectionClick());
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
              contentColor: iconColor,
              child: iconWidget ?? Icon(icon, size: 22, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.rank,
    required this.followersCount,
    required this.followingCount,
    required this.showFollowing,
    required this.isExpert,
  });

  final ProfileRank rank;
  final int followersCount;
  final int followingCount;
  final bool showFollowing;
  final bool isExpert;

  @override
  Widget build(BuildContext context) {
    final progress = rank.nextRankPoints <= 0
        ? 1.0
        : (rank.progressPoints / rank.nextRankPoints).clamp(0.0, 1.0);

    return Semantics(
      label: isExpert ? 'Профиль эксперта' : 'Профиль путешественника',
      child: Container(
        key: const ValueKey('profile-rank-card'),
        padding: EdgeInsets.all(isExpert ? 2 : 0),
        decoration: BoxDecoration(
          color: isExpert ? null : AppColors.elevatedSurface,
          gradient: isExpert ? AppExpertStyle.gradient : null,
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: AppShadows.tile,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface,
            borderRadius: BorderRadius.circular(AppRadii.card - 2),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FollowStatBox(
                        key: const ValueKey('profile-followers-stat'),
                        iconAsset: AppIconography.profileSelected,
                        useFollowersIcon: true,
                        value: compactCount(followersCount),
                        label: 'Подписчиков',
                      ),
                    ),
                    if (showFollowing) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FollowStatBox(
                          key: const ValueKey('profile-following-stat'),
                          iconAsset: AppIconography.heart,
                          value: compactCount(followingCount),
                          label: 'Подписок',
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE8E8E8),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Звание:',
                      style: AppTypography.greetingSubtitle.copyWith(
                        color: AppColors.primaryInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
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
                const SizedBox(height: 10),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE8E8E8),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.capsule),
                        child: SizedBox(
                          height: 30,
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
                                  rank.nextRankPoints <= 0
                                      ? '${rank.progressPoints} тп'
                                      : '${rank.progressPoints} / ${rank.nextRankPoints} тп',
                                  style: AppTypography.chip.copyWith(
                                    fontSize: 12,
                                    color: progress > 0.45
                                        ? Colors.white
                                        : AppColors.primaryInk,
                                    fontWeight: FontWeight.w400,
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
                      height: 30,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.controlSurface,
                        borderRadius: BorderRadius.circular(AppRadii.capsule),
                      ),
                      child: Text(
                        'Топ ${rank.leaderboardPlace}',
                        style: AppTypography.chip.copyWith(
                          fontSize: 12,
                          color: AppColors.primaryInk,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowStatBox extends StatelessWidget {
  const _FollowStatBox({
    required this.iconAsset,
    required this.value,
    required this.label,
    this.useFollowersIcon = false,
    super.key,
  });

  final String iconAsset;
  final String value;
  final String label;
  final bool useFollowersIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.fromLTRB(11, 7, 11, 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryInk, width: 2),
      ),
      child: Row(
        children: [
          if (useFollowersIcon)
            const _FollowersStatIcon(
              key: ValueKey('profile-followers-icon'),
              size: 30,
            )
          else
            AppAssetIcon(iconAsset, size: 30, color: AppColors.profileStatIcon),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.greeting.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.greetingSubtitle.copyWith(
                    fontSize: 12,
                    height: 1,
                    color: AppColors.secondaryInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vector rendering of the supplied `Group.svg`, kept sharp at every scale.
class _FollowersStatIcon extends StatelessWidget {
  const _FollowersStatIcon({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _FollowersStatIconPainter(),
    );
  }
}

class _FollowersStatIconPainter extends CustomPainter {
  const _FollowersStatIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 26;
    canvas.scale(scale);
    final stroke = Paint()
      ..color = AppColors.profileStatIcon
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.drawOval(const Rect.fromLTRB(5.54, 0.875, 14.875, 10.208), stroke);

    final shoulders = Path()
      ..moveTo(19.542, 18.958)
      ..cubicTo(19.542, 21.858, 19.542, 24.208, 10.208, 24.208)
      ..cubicTo(0.875, 24.208, 0.875, 21.858, 0.875, 18.958)
      ..cubicTo(0.875, 16.059, 5.054, 13.708, 10.208, 13.708)
      ..cubicTo(15.363, 13.708, 19.542, 16.059, 19.542, 18.958)
      ..close();
    canvas.drawPath(shoulders, stroke);

    final heart = Path()
      ..moveTo(20.708, 13.708)
      ..cubicTo(20.15, 13.27, 17.208, 11.48, 17.208, 9.857)
      ..cubicTo(17.208, 7.73, 19.49, 7.12, 20.708, 8.626)
      ..cubicTo(21.926, 7.12, 24.208, 7.73, 24.208, 9.857)
      ..cubicTo(24.208, 11.48, 21.266, 13.27, 20.708, 13.708)
      ..close();
    canvas.drawPath(heart, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    final unlocked = achievement.isUnlocked;
    return SizedBox(
      width: double.infinity,
      child: AppPressableScale(
        borderRadius: AppRadii.card,
        onTap: unlocked ? onTap : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: unlocked
                ? AppColors.elevatedSurface
                : const Color(0x59E7E7E7),
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: unlocked ? AppShadows.tile : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: unlocked
                        ? AppColors.accentBlue
                        : const Color(0xFFCFCFD2),
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
                          color: unlocked
                              ? AppColors.primaryInk
                              : AppColors.secondaryInk,
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
    required this.showStatuses,
    required this.authorIsExpert,
    this.authorAvatarUrl,
  });

  final List<RouteSummary> routes;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;
  final bool showStatuses;
  final bool authorIsExpert;
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
                  tags: showStatuses
                      ? [?routeStatusLabel(routes[index])]
                      : const [],
                  interactive: true,
                  authorAvatarUrl: authorAvatarUrl,
                  authorIsExpert: authorIsExpert,
                  onEdit: showStatuses
                      ? () => context.pushNamed(AppRouteNames.routePublish)
                      : null,
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
