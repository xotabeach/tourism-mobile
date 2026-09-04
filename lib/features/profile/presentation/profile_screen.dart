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
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/core/design/components/collapsing_hero_header.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/article_card.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';
import 'package:tourism_mobile/features/profile/presentation/achievement_card_screen.dart';
import 'package:tourism_mobile/features/profile/presentation/widgets/achievement_icons.dart';
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
                    child: _ActivityStatsRow(
                      completedRoutesCount: profile.completedRoutesCount,
                      publishedRoutesCount: profile.publishedRoutesCount,
                      reviewsWrittenCount: profile.reviewsWrittenCount,
                      totalDistanceMeters: profile.totalDistanceMeters,
                      publishedArticlesCount: profile.publishedArticlesCount,
                      articleLikesCount: profile.articleLikesCount,
                    ),
                  ),
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
                    onAchievementTap: (achievement) =>
                        openAchievementCard(context, achievement),
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
                      authorAvatarUrl: profile.avatarImageUrl,
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  _ProfileArticlesSection(
                    isOwn: isOwn,
                    authorUserId: widget.userId,
                  ),
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

/// "Статьи"/"Мои статьи" — a section of its own kept independent of
/// [ProfileSnapshot], the same way route/place reviews are fetched
/// separately rather than baked into the profile aggregate.
/// Высота карточки статьи в профиле — с макета: чуть ниже полноразмерной,
/// потому что карточка здесь ýже и в ней меньше строк.
const _articleCardHeight = 306.0;

class _ProfileArticlesSection extends ConsumerWidget {
  const _ProfileArticlesSection({
    required this.isOwn,
    required this.authorUserId,
  });

  final bool isOwn;
  final String? authorUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = isOwn
        ? ref.watch(myArticlesProvider)
        : (authorUserId == null
              ? const AsyncValue.data(ArticleListPage(items: [], total: 0))
              : ref.watch(articlesByAuthorProvider(authorUserId!)));
    final articles = page.valueOrNull?.items ?? const [];
    // Пока грузится, список пуст — и владелец профиля видел «Вы ещё не
    // написали ни одной статьи», хотя статьи есть. Показываем силуэт карточки.
    final isLoading = page.isLoading && page.valueOrNull == null;
    // Someone else's empty article list is nothing to show; one's own is an
    // invitation to write the first one.
    if (articles.isEmpty && !isOwn) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isOwn ? 'Мои статьи' : 'Статьи',
                  style: AppTypography.sectionTitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isOwn)
                Semantics(
                  button: true,
                  label: 'Написать статью',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    onTap: () => unawaited(
                      context.pushNamed(AppRouteNames.articleEditor),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(10, 6, 6, 6),
                      child: Row(
                        children: [
                          Text('Написать', style: AppTypography.sectionAction),
                          SizedBox(width: 2),
                          Icon(
                            Icons.add_rounded,
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
        const SizedBox(height: AppSpacing.sm),
        if (isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: ArticleCardSkeleton(
              width: profileCardWidth(context),
              height: _articleCardHeight,
            ),
          )
        else if (articles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Text(
              'Вы ещё не написали ни одной статьи',
              style: AppTypography.routeMetadata,
            ),
          )
        else
          // Ряд карточек, а не столбец: на макете статьи в профиле листаются
          // так же, как маршруты над ними, и оба ряда идут одним ритмом.
          _ProfileCardsCarousel(
            itemCount: articles.length,
            height: _articleCardHeight,
            itemBuilder: (context, index, width) => ArticleCard(
              article: articles[index],
              width: width,
              height: _articleCardHeight,
              showStatus: isOwn,
            ),
          ),
      ],
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
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: isExpert ? 2 : 0),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(16),
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
  // Photo runs to y≈207 and tucks 35 px behind the card (design exports).
  static const double coverBody = 207;
  // 16 pad + 45 stat pill + 10 + 1 divider + 35 rank row + 1 divider + 8 +
  // 26 progress + 18 pad — measured off the 393 px Frame 146 export, plus a
  // touch more breathing room around the stat pills and the bottom edge.
  static const double rankCardHeight = 167;
  // Experts have no points progress bar / leaderboard row (admin-granted
  // rank, not points-based) — the card ends after the rank row (Frame 147).
  static const double rankCardHeightExpert = 124;
  static const double rankOverlap = 41;

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
    final cardHeight = isExpert ? rankCardHeightExpert : rankCardHeight;
    final expandedHeight = coverHeight + cardHeight - rankOverlap;

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
                    height: cardHeight - rankOverlap,
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
                    bottom: cardHeight + identityAboveRank,
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
                            radius: 30,
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
                                // Frame 146/147 wrap "Никита Можаров" onto two
                                // lines rather than truncating it.
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.greeting.copyWith(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile.rank.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.greetingSubtitle.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 13,
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
                    height: cardHeight,
                    child: Transform.translate(
                      key: const ValueKey('profile-pull-rank'),
                      offset: Offset(0, pullDownOffset),
                      child: _RankCard(
                        rank: profile.rank,
                        followersCount: profile.followersCount,
                        followingCount: profile.followingCount,
                        showFollowing: isOwn,
                        isExpert: isExpert,
                        expertTitle: profile.expertTitle,
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
                        // 22, а не 16: рядом с именем в 16pt и круглой
                        // кнопкой справа аватар в 32px читался мелко
                        // (замечание 2026-09-04).
                        CircleAvatar(
                          radius: 22,
                          backgroundImage: avatarAsset,
                          foregroundImage: avatarNetwork,
                        ),
                        const SizedBox(width: 12),
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
      child: AppGlassCircle(
        dimension: 44,
        blur: 10,
        fillColor: fillColor,
        borderColor: Colors.white.withValues(alpha: 0.28),
        contentColor: iconColor,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              unawaited(AppHaptics.selectionClick());
              onTap();
            },
            customBorder: const CircleBorder(),
            child: Center(
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
    this.expertTitle,
  });

  final ProfileRank rank;
  final int followersCount;
  final int followingCount;
  final bool showFollowing;
  final bool isExpert;
  final String? expertTitle;

  static const _fallbackExpertTitle = 'Эксперт КрымТрип';

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
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
                const SizedBox(height: 10),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.hairline,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Звание:',
                      style: AppTypography.greetingSubtitle.copyWith(
                        color: AppColors.secondaryInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: isExpert
                          ? ShaderMask(
                              shaderCallback: (bounds) =>
                                  AppExpertStyle.gradient.createShader(bounds),
                              child: Text(
                                expertTitle?.trim().isNotEmpty ?? false
                                    ? expertTitle!.trim()
                                    : _fallbackExpertTitle,
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.greeting.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              rank.title,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.greeting.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                    ),
                  ],
                ),
                // Experts carry an admin-granted rank, not a points-based
                // one — no progress bar / leaderboard row for them.
                if (!isExpert) ...[
                  const SizedBox(height: 12),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.hairline,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryInk,
                            borderRadius: BorderRadius.circular(
                              AppRadii.capsule,
                            ),
                          ),
                          child: Text(
                            rank.nextRankPoints <= 0
                                ? '${rank.progressPoints} тп'
                                : '${rank.progressPoints} / ${rank.nextRankPoints} тп',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.chip.copyWith(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        height: 26,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.pageSurface,
                          borderRadius: BorderRadius.circular(AppRadii.capsule),
                        ),
                        child: Text(
                          'Топ ${rank.leaderboardPlace}',
                          style: AppTypography.chip.copyWith(
                            fontSize: 12,
                            color: AppColors.secondaryInk,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the traveller has done — two rows of stat boxes below the header,
/// reusing [_FollowStatBox]'s look so it reads as one design language with
/// the followers/following row above it.
///
/// Routes are split across "Пройдено" and "Опубликовано": one "Маршрутов"
/// box answered neither question, and a reader could not tell whether the
/// number meant walking or authoring (asked 2026-09-04).
class _ActivityStatsRow extends StatelessWidget {
  const _ActivityStatsRow({
    required this.completedRoutesCount,
    required this.publishedRoutesCount,
    required this.reviewsWrittenCount,
    required this.totalDistanceMeters,
    required this.publishedArticlesCount,
    required this.articleLikesCount,
  });

  final int completedRoutesCount;
  final int publishedRoutesCount;
  final int reviewsWrittenCount;
  final int totalDistanceMeters;
  final int publishedArticlesCount;
  final int articleLikesCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _FollowStatBox(
                key: const ValueKey('profile-completed-routes-stat'),
                iconAsset: AppIconography.routes,
                value: compactCount(completedRoutesCount),
                label: 'Пройдено',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FollowStatBox(
                key: const ValueKey('profile-published-routes-stat'),
                iconAsset: AppIconography.map,
                value: compactCount(publishedRoutesCount),
                label: 'Маршрутов',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FollowStatBox(
                key: const ValueKey('profile-distance-stat'),
                iconAsset: AppIconography.map,
                value: formatDistanceKm(totalDistanceMeters),
                label: 'Километров',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _FollowStatBox(
                key: const ValueKey('profile-articles-stat'),
                iconAsset: AppIconography.settingsRate,
                value: compactCount(publishedArticlesCount),
                label: 'Статей',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FollowStatBox(
                key: const ValueKey('profile-article-likes-stat'),
                iconAsset: AppIconography.settingsRate,
                value: compactCount(articleLikesCount),
                label: 'Лайков',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FollowStatBox(
                key: const ValueKey('profile-reviews-stat'),
                iconAsset: AppIconography.settingsRate,
                value: compactCount(reviewsWrittenCount),
                label: 'Отзывов',
              ),
            ),
          ],
        ),
      ],
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
    // Geometry/colors measured from the 393 px design export (Frame 146/147),
    // with a touch more vertical breathing room than the raw measurement and
    // a soft drop shadow instead of a hairline outline.
    return Container(
      height: 45,
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppShadows.tile,
      ),
      child: Row(
        children: [
          if (useFollowersIcon)
            const _FollowersStatIcon(
              key: ValueKey('profile-followers-icon'),
              size: 28,
            )
          else
            AppAssetIcon(iconAsset, size: 28, color: AppColors.profileStatIcon),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.greetingSubtitle.copyWith(
                    fontSize: 11,
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
                  // Тот же глиф, что на карточке достижения. Без него кружок
                  // читался как незагрузившаяся картинка.
                  child: Icon(
                    achievementIconFor(achievement.iconSlug),
                    size: 24,
                    color: unlocked ? Colors.white : AppColors.secondaryInk,
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

/// Ширина карточки в профиле: следующая карточка выглядывает справа — так на
/// макете, и по этому «хвосту» сразу видно, что список листается. На весь
/// экран карточки выглядели как одиночные и занимали половину профиля.
double profileCardWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width - AppSpacing.page - 56;

/// Карусель карточек профиля с точками под ней. Один и тот же ритм у
/// маршрутов и у статей — на макете это два одинаковых ряда.
class _ProfileCardsCarousel extends StatefulWidget {
  const _ProfileCardsCarousel({
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index, double width)
  itemBuilder;
  final double height;

  @override
  State<_ProfileCardsCarousel> createState() => _ProfileCardsCarouselState();
}

class _ProfileCardsCarouselState extends State<_ProfileCardsCarousel> {
  PageController? _controller;
  double _fraction = 1;
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width;
    final fraction = (profileCardWidth(context) + AppSpacing.page) / width;
    if (_controller == null || (fraction - _fraction).abs() > 0.001) {
      _controller?.dispose();
      _fraction = fraction;
      _controller = PageController(viewportFraction: fraction);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = profileCardWidth(context);
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.itemCount,
            padEnds: false,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) => Padding(
              // Отступ слева у каждой страницы: у первой это поле экрана,
              // у остальных — промежуток между карточками.
              padding: const EdgeInsets.only(left: AppSpacing.page),
              child: widget.itemBuilder(context, index, cardWidth),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PageDots(count: widget.itemCount, index: _page),
      ],
    );
  }
}

class _PublishedRoutesCarousel extends StatelessWidget {
  const _PublishedRoutesCarousel({
    required this.routes,
    required this.showStatuses,
    required this.authorIsExpert,
    this.authorAvatarUrl,
  });

  static const cardHeight = 296.0;

  final List<RouteSummary> routes;
  final bool showStatuses;
  final bool authorIsExpert;
  final String? authorAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return _ProfileCardsCarousel(
      itemCount: routes.length,
      height: cardHeight,
      itemBuilder: (context, index, width) => SizedBox(
        width: width,
        child: RouteHeroCard(
          route: routes[index],
          height: cardHeight,
          tags: showStatuses ? [?routeStatusLabel(routes[index])] : const [],
          interactive: true,
          authorAvatarUrl: authorAvatarUrl,
          authorIsExpert: authorIsExpert,
          onEdit: showStatuses
              ? () => context.pushNamed(AppRouteNames.routePublish)
              : null,
        ),
      ),
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
