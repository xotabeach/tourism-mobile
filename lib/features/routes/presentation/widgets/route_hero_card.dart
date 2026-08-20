import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_expert_style.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/routing/app_router.dart';

enum RouteCardVariant { list, deck }

int difficultyBolts(String? difficulty) {
  return switch (difficulty) {
    'easy' => 2,
    'moderate' => 3,
    'hard' => 4,
    'expert' => 5,
    _ => 2,
  };
}

String difficultyLabel(String? difficulty) {
  return switch (difficulty) {
    'easy' => 'Лёгкий',
    'moderate' => 'Средний',
    'hard' => 'Сложный',
    'expert' => 'Экстрим',
    _ => 'Маршрут',
  };
}

String transportLabel(String? mode) {
  return switch (mode) {
    'walk' || 'foot' || 'hiking' => 'Пешком',
    'car' => 'На авто',
    'bike' => 'Вело',
    'public_transport' => 'Транспорт',
    _ => 'Маршрут',
  };
}

String? routeStatusLabel(RouteSummary route) {
  return switch (route.publicationStatus) {
    'draft' => 'Черновик',
    'pending_review' => 'На модерации',
    'rejected' => 'Нужны правки',
    'published' when route.visibility != null && route.visibility != 'public' =>
      'Скрыт',
    _ => null,
  };
}

String formatDistanceKm(int? meters) {
  if (meters == null) {
    return '—';
  }
  final km = meters / 1000;
  final text = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
  return '$text км'.replaceAll('.', ',');
}

String routeLocality(RouteSummary route) {
  if (route.slug.contains('bakhchisaray') || route.slug.contains('chok-sary')) {
    return 'Бахчисарай';
  }
  if (route.slug.contains('south-coast') || route.slug.contains('ai-petri')) {
    return 'Ялта';
  }
  if (route.slug.contains('coast') || route.slug.contains('fiolent')) {
    return 'Фиолент';
  }
  return 'Крым';
}

/// Photo-first route card shared by list and swipe deck layouts.
class RouteHeroCard extends ConsumerWidget {
  const RouteHeroCard({
    required this.route,
    this.height = 304,
    this.tags = const [],
    this.interactive = true,
    this.variant = RouteCardVariant.list,
    this.visualProgress = 0,
    this.authorAvatarUrl,
    this.authorIsExpert,
    this.onFavoriteToggle,
    this.onEdit,
    super.key,
  });

  final RouteSummary route;
  final double height;
  final List<String> tags;
  final bool interactive;
  final RouteCardVariant variant;

  /// Absolute swipe progress used to fade card actions under a semantic overlay.
  final double visualProgress;

  /// Optional author avatar (resolved https / `file://`). Falls back to the
  /// current session avatar when the route author matches the signed-in user.
  final String? authorAvatarUrl;

  /// Optional context override (for profile-owned carousels). API-backed
  /// catalogs normally use [RouteSummary.authorIsExpert].
  final bool? authorIsExpert;

  /// Lets list owners coordinate a favorite change with their own removal
  /// animation. Other cards keep using [favoritesProvider] directly.
  final Future<void> Function()? onFavoriteToggle;

  /// Optional edit control for the owner's published-route carousel.
  final VoidCallback? onEdit;

  void _openAuthor(BuildContext context, WidgetRef ref) {
    final ownerId = route.ownerUserId;
    if (ownerId == null || ownerId.isEmpty) {
      return;
    }
    final session = ref.read(sessionProvider);
    if (session.userId != null && session.userId == ownerId) {
      context.goNamed(AppRouteNames.profile);
      return;
    }
    unawaited(
      context.pushNamed(
        AppRouteNames.userProfile,
        pathParameters: {'userId': ownerId},
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(sessionProvider);
    final resolvedAuthorAvatar = authorAvatarUrl ?? route.authorAvatarUrl;
    final authorName = route.authorLabel ?? '';
    final sessionName = session.displayName?.trim() ?? '';
    final isOwnRoute =
        (route.ownerUserId != null && route.ownerUserId == session.userId) ||
        (resolvedAuthorAvatar != null) ||
        (sessionName.isNotEmpty &&
            (authorName == sessionName ||
                authorName.startsWith(sessionName.split(' ').first)));
    final avatar = AppImages.avatarProvider(
      config: config,
      avatarUrl:
          resolvedAuthorAvatar ?? (isOwnRoute ? session.avatarUrl : null),
    );
    final canOpenAuthor =
        route.ownerUserId != null && route.ownerUserId!.isNotEmpty;
    final resolvedAuthorIsExpert = authorIsExpert ?? route.authorIsExpert;
    final card = RepaintBoundary(
      child: _RouteCardContent(
        route: route,
        config: config,
        height: height,
        tags: tags,
        variant: variant,
        visualProgress: visualProgress.clamp(0, 1),
        authorAvatar: avatar,
        authorIsExpert: resolvedAuthorIsExpert,
        onAuthorTap: canOpenAuthor ? () => _openAuthor(context, ref) : null,
        onFavoriteToggle: onFavoriteToggle,
        onEdit: onEdit,
      ),
    );

    if (!interactive) {
      return card;
    }

    return AppPressableScale(
      borderRadius: AppRadii.card,
      onTap: () => context.pushNamed(
        AppRouteNames.routeDetails,
        pathParameters: {'id': route.id},
        extra: route,
      ),
      child: card,
    );
  }
}

class _RouteCardContent extends StatelessWidget {
  const _RouteCardContent({
    required this.route,
    required this.config,
    required this.height,
    required this.tags,
    required this.variant,
    required this.visualProgress,
    required this.authorAvatar,
    required this.authorIsExpert,
    this.onAuthorTap,
    this.onFavoriteToggle,
    this.onEdit,
  });

  final RouteSummary route;
  final AppConfig config;
  final double height;
  final List<String> tags;
  final RouteCardVariant variant;
  final double visualProgress;
  final ImageProvider authorAvatar;
  final bool authorIsExpert;
  final VoidCallback? onAuthorTap;
  final Future<void> Function()? onFavoriteToggle;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final bolts = difficultyBolts(route.difficulty);
    final chipTags = tags.isNotEmpty
        ? tags
        : [
            difficultyLabel(route.difficulty),
            transportLabel(route.transportMode),
          ];
    final actionOpacity = (1 - visualProgress * 1.35).clamp(0.0, 1.0);
    final compact = variant == RouteCardVariant.list;
    final publiclyAvailable =
        route.publicationStatus == null ||
        (route.publicationStatus == 'published' &&
            (route.visibility == null || route.visibility == 'public'));

    return AppExpertFrame(
      isExpert: authorIsExpert,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImages.coverImage(
                config: config,
                coverImageUrl: route.coverImageUrl,
                fallbackSeed: route.slug,
                alignment: route.slug.contains('south-coast')
                    ? const Alignment(-0.12, 0)
                    : Alignment.center,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x45000000),
                      Color(0x00000000),
                      Color(0xBF000000),
                    ],
                    stops: [0, 0.36, 1],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 14 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onAuthorTap,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(
                                    authorIsExpert ? 2 : 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: authorIsExpert
                                        ? null
                                        : Colors.white.withValues(alpha: 0.9),
                                    gradient: authorIsExpert
                                        ? AppExpertStyle.gradient
                                        : null,
                                    shape: BoxShape.circle,
                                  ),
                                  child: CircleAvatar(
                                    radius: 18.5,
                                    backgroundImage: authorAvatar,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              route.authorLabel ?? 'Никита',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.chip
                                                  .copyWith(
                                                    fontSize: 15,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                          if (authorIsExpert) ...[
                                            const SizedBox(width: 7),
                                            const AppExpertBadge(compact: true),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        route.authorLabel?.contains(
                                                  'редакция',
                                                ) ??
                                                false
                                            ? transportLabel(
                                                route.transportMode,
                                              )
                                            : 'Продвинутый пешеход',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.routeMetadata
                                            .copyWith(
                                              fontSize: 12,
                                              color: Colors.white.withValues(
                                                alpha: 0.8,
                                              ),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        if (onEdit != null)
                          AppFilteredOpacity(
                            opacity: actionOpacity,
                            child: _EditRouteButton(onTap: onEdit!),
                          ),
                        if (onEdit != null && publiclyAvailable)
                          const SizedBox(width: 8),
                        if (publiclyAvailable)
                          AppFilteredOpacity(
                            opacity: actionOpacity,
                            child: _FavoriteButton(
                              routeId: route.id,
                              onToggle: onFavoriteToggle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (height >= 260)
                      AppFilteredOpacity(
                        opacity: actionOpacity,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final tag in chipTags.take(3))
                              _RouteTag(label: tag),
                          ],
                        ),
                      ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _RatingPill(route: route),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                route.name,
                                maxLines: height >= 260 ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.routeTitle.copyWith(
                                  color: Colors.white,
                                  fontSize: compact ? 22 : 24,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _RouteMetadata(route: route),
                              if (!compact) ...[
                                const SizedBox(height: AppSpacing.xs),
                                _DifficultyRow(
                                  bolts: bolts,
                                  label: difficultyLabel(route.difficulty),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppFilteredOpacity(
                          opacity: actionOpacity,
                          child: AppGlassCircle(
                            dimension: compact ? 50 : 56,
                            blur: 12,
                            fillColor: Colors.white.withValues(alpha: 0.3),
                            borderColor: Colors.white.withValues(alpha: 0.34),
                            contentColor: Colors.white,
                            child: AppAssetIcon(
                              AppIconography.arrow,
                              color: Colors.white,
                              size: compact ? 26 : 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteTag extends StatelessWidget {
  const _RouteTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AppGlassPill(
      blur: 8,
      fillColor: Colors.black.withValues(alpha: 0.38),
      borderColor: Colors.white.withValues(alpha: 0.14),
      contentColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      child: Text(
        label,
        style: AppTypography.routeMetadata.copyWith(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.route});

  final RouteSummary route;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(AppRadii.capsule),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: AppColors.rating, size: 17),
            const SizedBox(width: 4),
            Text(
              '4,${9 - (route.name.length % 3)}',
              style: AppTypography.routeMetadata.copyWith(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMetadata extends StatelessWidget {
  const _RouteMetadata({required this.route});

  final RouteSummary route;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.routeMetadata.copyWith(
      fontSize: 14,
      color: Colors.white.withValues(alpha: 0.82),
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(routeLocality(route), style: style),
        Container(
          width: 1,
          height: 15,
          color: Colors.white.withValues(alpha: 0.42),
        ),
        Icon(
          Icons.near_me_outlined,
          size: 15,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        Text(formatDistanceKm(route.distanceMeters), style: style),
      ],
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({required this.bolts, required this.label});

  final int bolts;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Сложность: $label, $bolts из 5',
      child: Row(
        children: [
          Text(
            'Сложность:',
            style: AppTypography.routeMetadata.copyWith(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          for (var index = 0; index < 5; index++)
            Icon(
              index < bolts ? Icons.bolt : Icons.bolt_outlined,
              size: 17,
              color: index < bolts
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.6),
            ),
        ],
      ),
    );
  }
}

class _EditRouteButton extends StatelessWidget {
  const _EditRouteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Редактировать маршрут',
      child: AppGlassCircle(
        dimension: 44,
        blur: 10,
        fillColor: Colors.black.withValues(alpha: 0.42),
        borderColor: Colors.white.withValues(alpha: 0.16),
        contentColor: Colors.white,
        child: IconButton(
          onPressed: onTap,
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _FavoriteButton extends ConsumerStatefulWidget {
  const _FavoriteButton({required this.routeId, this.onToggle});

  final String routeId;
  final Future<void> Function()? onToggle;

  @override
  ConsumerState<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.emphasized,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.22), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 1), weight: 55),
    ]).animate(CurvedAnimation(parent: _controller, curve: AppMotion.standard));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    unawaited(AppHaptics.selectionClick());
    unawaited(_controller.forward(from: 0));
    try {
      final onToggle = widget.onToggle;
      if (onToggle == null) {
        await ref.read(favoritesProvider.notifier).toggleRoute(widget.routeId);
      } else {
        await onToggle();
      }
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить избранное')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(
      favoritesProvider.select(
        (state) => state.routeIds.contains(widget.routeId),
      ),
    );
    return Semantics(
      key: ValueKey('favorite-toggle-${widget.routeId}'),
      button: true,
      toggled: selected,
      label: selected ? 'Удалить из избранного' : 'Добавить в избранное',
      child: AppGlassCircle(
        dimension: 44,
        blur: 10,
        fillColor: Colors.black.withValues(alpha: 0.42),
        borderColor: Colors.white.withValues(alpha: 0.16),
        contentColor: Colors.white,
        child: IconButton(
          onPressed: _toggle,
          padding: EdgeInsets.zero,
          icon: ScaleTransition(
            scale: _scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (selected)
                  const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                AppAssetIcon(
                  AppIconography.heart,
                  color: Colors.white.withValues(alpha: selected ? 0.35 : 1),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BuildRouteBanner extends StatelessWidget {
  const BuildRouteBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPressableScale(
      borderRadius: AppRadii.card,
      onTap: () => context.goNamed(AppRouteNames.routeMatch),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: SizedBox(
          height: 246,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                AppImages.coastPineTwilight,
                fit: BoxFit.cover,
                alignment: const Alignment(0.05, 0),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x1F000000),
                      Color(0x26000000),
                      Color(0xC9000000),
                    ],
                    stops: [0, 0.48, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppGlassPill(
                      blur: 10,
                      fillColor: Colors.black.withValues(alpha: 0.42),
                      borderColor: Colors.white.withValues(alpha: 0.82),
                      contentColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        '> 250 маршрутов',
                        style: AppTypography.chip.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ПОСТРОЙ\nМАРШРУТ',
                                style: AppTypography.welcomeTitle.copyWith(
                                  color: Colors.white,
                                  fontSize: 26,
                                  height: 1.06,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Подбери маршрут для себя\nпо всем параметрам',
                                style: AppTypography.routeMetadata.copyWith(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13,
                                  height: 1.42,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppGlassCircle(
                          dimension: 52,
                          blur: 12,
                          fillColor: Colors.white.withValues(alpha: 0.34),
                          borderColor: Colors.white.withValues(alpha: 0.24),
                          contentColor: Colors.white,
                          child: const AppAssetIcon(
                            AppIconography.arrow,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
