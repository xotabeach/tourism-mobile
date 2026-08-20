import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_expert_style.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/places/presentation/place_details_screen.dart';
import 'package:tourism_mobile/features/routes/application/route_reviews_providers.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/data/route_reviews_repository.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_collapsing_header.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_preview.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class RouteDetailsScreen extends ConsumerStatefulWidget {
  const RouteDetailsScreen({
    required this.routeId,
    this.initialRoute,
    super.key,
  });

  static const routePath = '/routes/:id';

  final String routeId;
  final RouteSummary? initialRoute;

  @override
  ConsumerState<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

enum _RouteDetailsSection { about, comments }

class _RouteDetailsScreenState extends ConsumerState<RouteDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  late final AnimationController _galleryController;

  int? _selectedStop;
  var _selectedSection = _RouteDetailsSection.about;

  @override
  void initState() {
    super.initState();
    _galleryController = AnimationController(
      vsync: this,
      duration: AppMotion.emphasized,
    );
    _scrollController.addListener(_onScrollCollapseGallery);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScrollCollapseGallery)
      ..dispose();
    _galleryController.dispose();
    super.dispose();
  }

  void _onScrollCollapseGallery() {
    if (_scrollController.offset > 24 && _galleryController.value > 0) {
      _settleGallery(0);
    }
  }

  void _toggleGallery() {
    if (_scrollController.hasClients && _scrollController.offset > 24) {
      return;
    }
    _settleGallery(_galleryController.value < 0.5 ? 1 : 0);
  }

  void _settleGallery(double target) {
    if (!mounted) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _galleryController.value = target;
      return;
    }
    final remaining = (target - _galleryController.value).abs();
    _galleryController.duration = Duration(
      milliseconds: (220 + 120 * remaining).round(),
    );
    unawaited(
      _galleryController.animateTo(target, curve: AppMotion.emphasizedCurve),
    );
  }

  void _selectStop(int index) => setState(() => _selectedStop = index);

  void _openPlace(RouteStop stop) {
    unawaited(
      PlaceDetailsScreen.openFromRoute(
        context,
        routeId: widget.routeId,
        placeId: stop.placeId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialRoute;
    final session = ref.watch(sessionProvider);
    final ownerPreview =
        initial != null &&
        initial.ownerUserId == session.userId &&
        (initial.publicationStatus != 'published' ||
            initial.visibility != 'public');
    final routeAsync = ownerPreview
        ? ref.watch(ownRouteDetailProvider(widget.routeId))
        : ref.watch(routeDetailProvider(widget.routeId));

    return Scaffold(
      backgroundColor: AppColors.elevatedSurface,
      body: routeAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        skipError: true,
        data: _buildContent,
        loading: () => widget.initialRoute == null
            ? const _RouteDetailsLoadingView()
            : _buildInitialContent(widget.initialRoute!),
        error: (_, _) => AppAsyncErrorView(
          onRetry: () => ownerPreview
              ? ref.invalidate(ownRouteDetailProvider(widget.routeId))
              : ref.invalidate(routeDetailProvider(widget.routeId)),
        ),
      ),
    );
  }

  Widget _buildContent(RouteDetail route) {
    final config = ref.watch(appConfigProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isFavorite = ref.watch(
      favoritesProvider.select((s) => s.routeIds.contains(route.id)),
    );
    final authorName = route.authorLabel ?? 'КрымТрип редакция';
    final statusLabel = routeStatusLabel(route);
    final publiclyAvailable =
        route.publicationStatus == null ||
        (route.publicationStatus == 'published' &&
            (route.visibility == null || route.visibility == 'public'));

    VoidCallback? onAuthorTap;
    if (route.ownerUserId != null) {
      onAuthorTap = () {
        final ownerId = route.ownerUserId!;
        final session = ref.read(sessionProvider);
        if (session.userId == ownerId) {
          context.goNamed(AppRouteNames.profile);
        } else {
          unawaited(
            context.pushNamed(
              AppRouteNames.userProfile,
              pathParameters: {'userId': ownerId},
            ),
          );
        }
      };
    }

    return AnimatedBuilder(
      animation: _galleryController,
      builder: (context, _) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: CustomScrollView(
          key: const ValueKey('route-details-list'),
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            RouteCollapsingHeader(
              images: _galleryImages(config, route),
              title: route.name,
              isFavorite: isFavorite,
              expansionProgress: _galleryController.value,
              onToggleGallery: _toggleGallery,
              heroTag: 'route-cover-${route.id}',
              onBack: () => context.pop(),
              onToggleFavorite: () => unawaited(_toggleFavorite(route.id)),
              showFavorite: publiclyAvailable,
              onShare: () => _showSoon('Поделиться маршрутом'),
              onDownload: () => _showSoon('Офлайн-режим'),
            ),
            // Lip lives in the header; body continues the sheet without
            // negative overlap (avoids author/photo z-fighting).
            SliverToBoxAdapter(
              child: ColoredBox(
                color: AppColors.elevatedSurface,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 8, 18, 118 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AuthorRow(
                        name: authorName,
                        subtitle: 'Продвинутый пешеход',
                        avatar: AppImages.avatarProvider(
                          config: config,
                          avatarUrl: route.authorAvatarUrl,
                        ),
                        isExpert: route.authorIsExpert,
                        onAuthorTap: onAuthorTap,
                        onMore: () => _showSoon('Меню маршрута'),
                      ),
                      if (statusLabel != null) ...[
                        const SizedBox(height: 12),
                        _OwnerRouteStatusBanner(
                          label: statusLabel,
                          status: route.publicationStatus,
                        ),
                      ],
                      const _SectionDivider(),
                      Text(
                        route.name,
                        key: const ValueKey('route-details-title'),
                        style: AppTypography.routeTitle.copyWith(
                          fontSize: 24,
                          height: 1.14,
                          color: AppColors.primaryInk,
                        ),
                      ),
                      if (route.description != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          route.description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.rubik,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 1.42,
                            color: AppColors.secondaryInk,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _RouteDetailsTabs(
                        selected: _selectedSection,
                        onSelected: (section) {
                          if (_selectedSection == section) {
                            return;
                          }
                          FocusManager.instance.primaryFocus?.unfocus();
                          setState(() => _selectedSection = section);
                        },
                      ),
                      const _SectionDivider(),
                      if (_selectedSection == _RouteDetailsSection.about) ...[
                        _AudioGuideCard(
                          title: route.name,
                          author: authorName,
                          image: _routeCover(config, route),
                          onPlay: () => _showSoon('Аудиогид'),
                        ),
                        const SizedBox(height: 16),
                        const _RouteTagsRow(
                          tags: ['Горы', 'С детьми', 'Пешком', 'Круглый год'],
                        ),
                        const SizedBox(height: 16),
                        _RouteFacts(route: route),
                        const _SectionDivider(),
                        const _SectionTitle('Карта маршрута:'),
                        const SizedBox(height: 14),
                        RouteMapPreview(
                          stops: route.stops,
                          selectedIndex: _selectedStop,
                          onPinTap: _selectStop,
                        ),
                        const SizedBox(height: 24),
                        const _SectionTitle('Остановки:'),
                        const SizedBox(height: 6),
                        for (var index = 0; index < route.stops.length; index++)
                          _StopRow(
                            stop: route.stops[index],
                            selected: _selectedStop == index,
                            showDivider: index != route.stops.length - 1,
                            onNumberTap: () => _selectStop(index),
                            onOpen: () => _openPlace(route.stops[index]),
                          ),
                        _SimilarRoutesSection(currentRouteId: route.id),
                      ] else ...[
                        _RouteReviewsSection(
                          routeId: route.id,
                          allowComposer: publiclyAvailable,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialContent(RouteSummary route) {
    final config = ref.watch(appConfigProvider);
    return ColoredBox(
      color: AppColors.elevatedSurface,
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          RouteCollapsingHeader(
            images: [_routeCover(config, route)],
            title: route.name,
            isFavorite: false,
            heroTag: 'route-cover-${route.id}',
            onBack: () => context.pop(),
            onToggleFavorite: () {},
            showFavorite:
                route.publicationStatus == null ||
                (route.publicationStatus == 'published' &&
                    (route.visibility == null || route.visibility == 'public')),
            onShare: () {},
            onDownload: () {},
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _RouteDetailsBodySkeleton(),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(String routeId) async {
    try {
      await ref.read(favoritesProvider.notifier).toggleRoute(routeId);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить избранное')),
      );
    }
  }

  void _showSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature появится позже')));
  }

  List<ImageProvider> _galleryImages(AppConfig config, RouteDetail route) {
    final uploadedImages = route.media
        .where((item) => item.isImage)
        .map((item) => _routeMediaImageProvider(config, item.url))
        .whereType<ImageProvider>()
        .toList(growable: false);
    if (uploadedImages.isNotEmpty) {
      return uploadedImages;
    }
    return [_routeCover(config, route)];
  }
}

class _RouteDetailsTabs extends StatelessWidget {
  const _RouteDetailsTabs({required this.selected, required this.onSelected});

  final _RouteDetailsSection selected;
  final ValueChanged<_RouteDetailsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: _RouteDetailsTab(
              key: const ValueKey('route-about-tab'),
              label: 'О маршруте',
              selected: selected == _RouteDetailsSection.about,
              onTap: () => onSelected(_RouteDetailsSection.about),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _RouteDetailsTab(
              key: const ValueKey('route-comments-tab'),
              label: 'Комментарии',
              selected: selected == _RouteDetailsSection.comments,
              onTap: () => onSelected(_RouteDetailsSection.comments),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteDetailsTab extends StatelessWidget {
  const _RouteDetailsTab({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.accentBlue : AppColors.elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: BorderSide(
            color: selected ? AppColors.accentBlue : const Color(0xFFE2E2E2),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.1,
                color: selected ? Colors.white : AppColors.primaryInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerRouteStatusBanner extends StatelessWidget {
  const _OwnerRouteStatusBanner({required this.label, required this.status});

  final String label;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final (icon, description) = switch (status) {
      'pending_review' => (
        Icons.schedule_rounded,
        'Маршрут проверяет команда модерации. Пока он виден только вам.',
      ),
      'rejected' => (
        Icons.info_outline_rounded,
        'Перед публикацией маршруту нужны исправления.',
      ),
      'draft' => (
        Icons.edit_note_rounded,
        'Это сохранённый черновик, доступный только вам.',
      ),
      _ => (
        Icons.visibility_off_outlined,
        'Маршрут скрыт от других путешественников.',
      ),
    };
    return Semantics(
      label: 'Статус маршрута: $label. $description',
      child: Container(
        key: const ValueKey('route-owner-status'),
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.accentBlue.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.accentBlue.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.accentBlue, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.chip.copyWith(
                      color: AppColors.primaryInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: AppTypography.routeMetadata.copyWith(
                      color: AppColors.secondaryInk,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteDetailsLoadingView extends StatelessWidget {
  const _RouteDetailsLoadingView();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return AppShimmer(
      child: ColoredBox(
        color: AppColors.elevatedSurface,
        child: Column(
          children: [
            AppSkeleton(
              width: double.infinity,
              height: topInset + 360,
              borderRadius: 0,
            ),
            const Expanded(child: _RouteDetailsBodySkeleton()),
          ],
        ),
      ),
    );
  }
}

class _RouteDetailsBodySkeleton extends StatelessWidget {
  const _RouteDetailsBodySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 22, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSkeleton(width: 44, height: 44, shape: BoxShape.circle),
              SizedBox(width: 10),
              AppSkeleton(width: 154, height: 18, borderRadius: 7),
            ],
          ),
          SizedBox(height: 20),
          AppSkeleton(width: 270, height: 25, borderRadius: 8),
          SizedBox(height: 10),
          AppSkeleton(width: double.infinity, height: 13, borderRadius: 6),
          SizedBox(height: 7),
          AppSkeleton(width: 310, height: 13, borderRadius: 6),
          SizedBox(height: 22),
          AppSkeleton(width: double.infinity, height: 46, borderRadius: 12),
          SizedBox(height: 16),
          AppSkeleton(width: double.infinity, height: 118, borderRadius: 16),
        ],
      ),
    );
  }
}

ImageProvider? _routeMediaImageProvider(AppConfig config, String value) {
  if (AppImages.isAssetPath(value)) {
    return AssetImage(value);
  }
  final resolved = AppImages.resolveMediaUrl(config, value);
  return resolved == null
      ? null
      : AppImages.imageProvider(resolvedUrl: resolved);
}

ImageProvider _routeCover(AppConfig config, RouteSummary route) {
  if (AppImages.isAssetPath(route.coverImageUrl)) {
    return AssetImage(route.coverImageUrl!);
  }
  final url = AppImages.resolveMediaUrl(config, route.coverImageUrl);
  if (url != null) {
    return AppImages.imageProvider(
      resolvedUrl: url,
      assetFallback: AppImages.routeFallbackAsset(route.slug),
    );
  }
  return AssetImage(AppImages.routeFallbackAsset(route.slug));
}

/// Other routes of the region, shown right before the reviews.
class _SimilarRoutesSection extends ConsumerWidget {
  const _SimilarRoutesSection({required this.currentRouteId});

  // Compact version of the shared 361×304 route-card proportion.
  static const double cardHeight = 210;
  static const double cardWidth = 250;
  static const double sectionHeight = 278;
  static const int maxItems = 6;

  final String currentRouteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(routesListProvider);
    final routes = page.valueOrNull?.items
        .where((item) => item.id != currentRouteId)
        .take(maxItems)
        .toList(growable: false);

    if (routes != null && routes.isEmpty) {
      return const SizedBox.shrink();
    }

    final viewportWidth = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: sectionHeight,
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: viewportWidth,
        maxWidth: viewportWidth,
        minHeight: sectionHeight,
        maxHeight: sectionHeight,
        child: SizedBox(
          key: const ValueKey('similar-routes-full-bleed'),
          width: viewportWidth,
          height: sectionHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: _SectionDivider(),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: _SectionTitle('Похожие маршруты:'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: cardHeight,
                child: routes == null
                    ? const _SimilarRoutesSkeleton()
                    : ListView.separated(
                        key: const ValueKey('similar-routes-list'),
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        itemCount: routes.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final route = routes[index];
                          return SizedBox(
                            width: cardWidth,
                            child: RouteHeroCard(
                              route: route,
                              height: cardHeight,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimilarRoutesSkeleton extends StatelessWidget {
  const _SimilarRoutesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      separatorBuilder: (context, _) => const SizedBox(width: 10),
      itemBuilder: (context, _) => Container(
        width: _SimilarRoutesSection.cardWidth,
        decoration: BoxDecoration(
          color: AppColors.controlSurface,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.name,
    required this.subtitle,
    required this.avatar,
    required this.isExpert,
    required this.onMore,
    this.onAuthorTap,
  });

  final String name;
  final String subtitle;
  final ImageProvider avatar;
  final bool isExpert;
  final VoidCallback onMore;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAuthorTap,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: AppExpertFrame(
                    isExpert: isExpert,
                    borderRadius: BorderRadius.circular(999),
                    child: CircleAvatar(backgroundImage: avatar),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppFonts.rubik,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                color: AppColors.primaryInk,
                              ),
                            ),
                          ),
                          if (isExpert) ...[
                            const SizedBox(width: 7),
                            const AppExpertBadge(compact: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                          color: AppColors.secondaryInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Меню маршрута',
          child: SizedBox.square(
            dimension: 48,
            child: Material(
              color: AppColors.primaryInk,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onMore,
                child: const Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 15),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F1)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppFonts.rubik,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.primaryInk,
      ),
    );
  }
}

class _AudioGuideCard extends StatelessWidget {
  const _AudioGuideCard({
    required this.title,
    required this.author,
    required this.image,
    required this.onPlay,
  });

  final String title;
  final String author;
  final ImageProvider image;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEDEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image(
              image: image,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => const SizedBox.square(
                dimension: 44,
                child: ColoredBox(color: AppColors.controlSurface),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.primaryInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                    color: AppColors.secondaryInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '2ч 48м 17с',
            style: TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.2,
              color: AppColors.secondaryInk,
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: 'Слушать аудиогид',
            child: SizedBox.square(
              dimension: 44,
              child: Material(
                color: AppColors.elevatedSurface,
                shape: const CircleBorder(
                  side: BorderSide(color: Color(0xFFE0E0E2)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPlay,
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 26,
                    color: AppColors.primaryInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteTagsRow extends StatelessWidget {
  const _RouteTagsRow({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF646464),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.1,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _RouteFacts extends StatelessWidget {
  const _RouteFacts({required this.route});

  final RouteDetail route;

  @override
  Widget build(BuildContext context) {
    final duration = route.estimatedDurationMinutes;
    final durationLabel = duration == null
        ? '—'
        : duration >= 60
        ? '${duration ~/ 60} ч ${duration % 60} мин'
        : '$duration мин';

    return Column(
      children: [
        _FactRow(
          icon: Icons.bolt_outlined,
          label: 'Сложность:',
          value: '${difficultyBolts(route.difficulty)}/5',
        ),
        _FactRow(
          icon: Icons.schedule_outlined,
          label: 'Время в пути:',
          value: durationLabel,
        ),
        _FactRow(
          icon: Icons.directions_car_outlined,
          label: 'Транспорт:',
          value: transportLabel(route.transportMode),
        ),
        _FactRow(
          icon: Icons.navigation_outlined,
          label: 'Расстояние:',
          value: formatDistanceKm(route.distanceMeters),
        ),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.primaryInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$label '),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryInk,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.2,
                color: AppColors.secondaryInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.selected,
    required this.showDivider,
    required this.onNumberTap,
    required this.onOpen,
  });

  final RouteStop stop;
  final bool selected;
  final bool showDivider;
  final VoidCallback onNumberTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (stop.visitDurationMinutes != null) '${stop.visitDurationMinutes} мин',
      if (stop.note != null) stop.note!,
      if (stop.isOptional) 'опционально',
    ].join(' · ');

    return Column(
      children: [
        AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.standard,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF1F2F4) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          child: Row(
            children: [
              Semantics(
                button: true,
                selected: selected,
                label: 'Показать остановку ${stop.position} на карте',
                child: GestureDetector(
                  onTap: onNumberTap,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: AppMotion.normal,
                    curve: AppMotion.standard,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryInk,
                      border: Border.all(
                        color: selected
                            ? AppColors.primaryInk.withValues(alpha: 0.25)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${stop.position}',
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.placeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: AppColors.primaryInk,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                          color: AppColors.secondaryInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _AdaptiveInlineIconButton(
                onPressed: onOpen,
                tooltip: 'Открыть место',
                icon: Icons.chevron_right_rounded,
                iconSize: 26,
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F1)),
      ],
    );
  }
}

class _AdaptiveInlineIconButton extends StatelessWidget {
  const _AdaptiveInlineIconButton({
    required this.onPressed,
    required this.tooltip,
    required this.icon,
    this.iconSize = 24,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: iconSize,
      color: AppColors.primaryInk,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
    );
    if (Theme.of(context).platform != TargetPlatform.iOS) {
      return button;
    }
    return AppGlassCircle(
      dimension: 44,
      blur: 22,
      fillColor: Colors.white.withValues(alpha: 0.5),
      borderColor: Colors.white.withValues(alpha: 0.8),
      child: button,
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating, required this.topLabel});

  final String rating;
  final String topLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryInk,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, size: 18, color: AppColors.rating),
              const SizedBox(width: 6),
              Text(
                rating,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          topLabel,
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: AppColors.primaryInk,
          ),
        ),
      ],
    );
  }
}

class _RouteReviewsSection extends ConsumerStatefulWidget {
  const _RouteReviewsSection({
    required this.routeId,
    required this.allowComposer,
  });

  final String routeId;
  final bool allowComposer;

  @override
  ConsumerState<_RouteReviewsSection> createState() =>
      _RouteReviewsSectionState();
}

enum _ReviewListFilter { all, newest, oldest, withPhoto }

class _RouteReviewsSectionState extends ConsumerState<_RouteReviewsSection> {
  final _composerFocus = FocusNode();
  var _filter = _ReviewListFilter.all;
  RouteReview? _replyTarget;

  @override
  void dispose() {
    _composerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.allowComposer) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: Text(
          'Отзывы можно оставлять только к опубликованным маршрутам',
          key: ValueKey('reviews-unpublished-hint'),
          style: TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 14,
            height: 1.35,
            color: AppColors.secondaryInk,
          ),
        ),
      );
    }

    final reviewsAsync = ref.watch(routeReviewsProvider(widget.routeId));
    final myReviewsAsync = ref.watch(myRouteReviewsProvider);
    final selfUserId = ref.watch(sessionProvider).userId;
    final pendingCandidates = myReviewsAsync.maybeWhen(
      data: (items) => items
          .where(
            (r) => r.routeId == widget.routeId && r.status == 'pending_review',
          )
          .toList(),
      orElse: () => const <RouteReview>[],
    );
    final allMineForRoute = myReviewsAsync.maybeWhen(
      data: (items) => [
        for (final review in items)
          if (review.routeId == widget.routeId) review,
      ],
      orElse: () => const <RouteReview>[],
    );
    RouteReview? ownRootReview;
    for (final review in allMineForRoute) {
      if (review.replyTo == null &&
          (review.status == 'published' || review.status == 'pending_review')) {
        ownRootReview = review;
        break;
      }
    }

    return reviewsAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => const _ReviewsLoadingSkeleton(),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Не удалось загрузить отзывы',
            style: TextStyle(color: AppColors.secondaryInk),
          ),
          TextButton(
            onPressed: () {
              ref.invalidate(routeReviewsProvider(widget.routeId));
              ref.invalidate(myRouteReviewsProvider);
            },
            child: const Text('Повторить'),
          ),
          const SizedBox(height: 12),
          if (ownRootReview == null || _replyTarget != null)
            _ReviewComposer(
              routeId: widget.routeId,
              focusNode: _composerFocus,
              replyTo: _replyTarget,
              onCancelReply: _cancelReply,
              onSubmitted: _cancelReply,
            ),
        ],
      ),
      data: (page) {
        final pendingMine = pendingReviewsNotYetPublished(
          pending: pendingCandidates,
          published: page.items,
        );
        final pinned = ownRootReview;
        final visible = _applyFilter([
          for (final review in page.items)
            if (review.id != pinned?.id) review,
        ]);
        final pendingOthers = [
          for (final review in pendingMine)
            if (review.id != pinned?.id) review,
        ];
        final ratingLabel = page.averageRating == null
            ? '—'
            : page.averageRating!.toStringAsFixed(1).replaceAll('.', ',');
        final topLabel = page.ratingCount == 0
            ? 'Пока нет отзывов'
            : '${page.ratingCount} ${_reviewsWord(page.ratingCount)}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RatingRow(rating: ratingLabel, topLabel: topLabel),
            const SizedBox(height: 14),
            if (pinned == null || _replyTarget != null) ...[
              _ReviewComposer(
                routeId: widget.routeId,
                focusNode: _composerFocus,
                replyTo: _replyTarget,
                onCancelReply: _cancelReply,
                onSubmitted: _cancelReply,
              ),
              const SizedBox(height: 14),
            ],
            if (pinned != null) ...[
              const Text(
                'Ваш отзыв',
                key: ValueKey('own-review-pinned-label'),
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryInk,
                ),
              ),
              const SizedBox(height: 8),
              _ReviewCard(
                key: ValueKey('own-review-pinned-${pinned.id}'),
                review: pinned,
                pending: pinned.status == 'pending_review',
                canDelete: _canDeleteReview(pinned, selfUserId),
                onReply: () => _startReply(pinned),
              ),
              const SizedBox(height: 14),
            ],
            AppFilterChipBar(
              labels: const ['Все', 'Новые', 'Старые', 'С фото'],
              selected: switch (_filter) {
                _ReviewListFilter.all => 'Все',
                _ReviewListFilter.newest => 'Новые',
                _ReviewListFilter.oldest => 'Старые',
                _ReviewListFilter.withPhoto => 'С фото',
              },
              onSelected: (label) {
                setState(() {
                  _filter = switch (label) {
                    'Новые' => _ReviewListFilter.newest,
                    'Старые' => _ReviewListFilter.oldest,
                    'С фото' => _ReviewListFilter.withPhoto,
                    _ => _ReviewListFilter.all,
                  };
                });
              },
            ),
            const SizedBox(height: 14),
            for (final review in pendingOthers) ...[
              _ReviewCard(
                review: review,
                pending: true,
                canDelete: _canDeleteReview(review, selfUserId),
                onReply: () => _startReply(review),
              ),
              const SizedBox(height: 12),
            ],
            for (final review in visible) ...[
              _ReviewCard(
                review: review,
                pending: false,
                canDelete: _canDeleteReview(review, selfUserId),
                onReply: () => _startReply(review),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  void _startReply(RouteReview review) {
    setState(() => _replyTarget = review);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _composerFocus.requestFocus();
      }
    });
  }

  void _cancelReply() {
    if (!mounted || _replyTarget == null) {
      return;
    }
    setState(() => _replyTarget = null);
  }

  List<RouteReview> _applyFilter(List<RouteReview> items) {
    switch (_filter) {
      case _ReviewListFilter.all:
        return items;
      case _ReviewListFilter.newest:
        return [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _ReviewListFilter.oldest:
        return [...items]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _ReviewListFilter.withPhoto:
        return [
          for (final review in items)
            if (review.media.isNotEmpty) review,
        ];
    }
  }

  static bool _canDeleteReview(RouteReview review, String? selfUserId) {
    if (!_ownsReview(review, selfUserId)) {
      return false;
    }
    final age = DateTime.now().toUtc().difference(review.createdAt.toUtc());
    return age <= const Duration(hours: 6);
  }

  static bool _ownsReview(RouteReview review, String? selfUserId) {
    return selfUserId != null &&
        selfUserId.isNotEmpty &&
        review.authorUserId == selfUserId;
  }

  static String _reviewsWord(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) {
      return 'отзыв';
    }
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'отзывы';
    }
    return 'отзывов';
  }
}

class _ReviewsLoadingSkeleton extends StatelessWidget {
  const _ReviewsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSkeleton(width: 72, height: 30, borderRadius: 12),
                AppSkeleton(width: 92, height: 18, borderRadius: 7),
              ],
            ),
            SizedBox(height: 14),
            AppSkeleton(width: double.infinity, height: 222, borderRadius: 16),
            SizedBox(height: 14),
            AppSkeleton(width: double.infinity, height: 36, borderRadius: 18),
            SizedBox(height: 14),
            AppSkeleton(width: double.infinity, height: 170, borderRadius: 16),
          ],
        ),
      ),
    );
  }
}

/// Pending cards that are not already present in the published list (by id).
@visibleForTesting
List<RouteReview> pendingReviewsNotYetPublished({
  required List<RouteReview> pending,
  required List<RouteReview> published,
}) {
  if (pending.isEmpty) {
    return const [];
  }
  final publishedIds = {for (final review in published) review.id};
  return [
    for (final review in pending)
      if (!publishedIds.contains(review.id)) review,
  ];
}

class _ReviewComposer extends ConsumerStatefulWidget {
  const _ReviewComposer({
    required this.routeId,
    required this.focusNode,
    required this.replyTo,
    required this.onCancelReply,
    required this.onSubmitted,
  });

  final String routeId;
  final FocusNode focusNode;
  final RouteReview? replyTo;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends ConsumerState<_ReviewComposer>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _composerKey = GlobalKey();
  var _rating = 5;
  var _sending = false;
  var _lastViewInset = 0.0;
  final _images = <XFile>[];

  static const _maxChars = 500;
  static const _maxImages = 6;
  static const _maxImageBytes = 10 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.focusNode.addListener(_onComposerFocusChange);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.focusNode.removeListener(_onComposerFocusChange);
    _controller.dispose();
    super.dispose();
  }

  void _onComposerFocusChange() {
    if (!widget.focusNode.hasFocus) {
      return;
    }
    _ensureComposerVisible(animate: true);
    _ensureComposerVisibleSoon();
  }

  double _keyboardInset() {
    final view = View.of(context);
    return MediaQueryData.fromView(view).viewInsets.bottom;
  }

  @override
  void didChangeMetrics() {
    if (!mounted) {
      return;
    }
    final inset = _keyboardInset();
    final opened = inset > _lastViewInset + 1;
    _lastViewInset = inset;
    if (opened || (inset > 0 && widget.focusNode.hasFocus)) {
      _ensureComposerVisible(animate: false);
      if (opened) {
        _ensureComposerVisibleSoon();
      }
    }
  }

  void _ensureComposerVisibleSoon() {
    for (final delay in const [
      Duration(milliseconds: 50),
      Duration(milliseconds: 160),
      Duration(milliseconds: 320),
    ]) {
      Future<void>.delayed(delay, () {
        if (!mounted || !widget.focusNode.hasFocus) {
          return;
        }
        _ensureComposerVisible(animate: false);
      });
    }
  }

  void _ensureComposerVisible({required bool animate}) {
    final targetContext = _composerKey.currentContext;
    if (targetContext == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.focusNode.hasFocus) {
        return;
      }
      final ctx = _composerKey.currentContext;
      if (ctx == null) {
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.55,
          duration: animate ? const Duration(milliseconds: 220) : Duration.zero,
          curve: Curves.easeOut,
        ),
      );
    });
  }

  Future<void> _pickImages() async {
    final available = _maxImages - _images.length;
    if (available <= 0 || _sending) {
      return;
    }
    try {
      final picked = await ImagePicker().pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 86,
        limit: available,
        requestFullMetadata: false,
      );
      final accepted = <XFile>[];
      for (final image in picked) {
        if (await image.length() <= _maxImageBytes) {
          accepted.add(image);
        }
      }
      if (!mounted) {
        return;
      }
      setState(() => _images.addAll(accepted.take(available)));
      if (accepted.length != picked.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото больше 10 МБ не добавлены')),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось выбрать фотографии')),
        );
      }
    }
  }

  Future<void> _submit() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      unawaited(context.pushNamed(AppRouteNames.authIdentity));
      return;
    }
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(routeReviewsRepositoryProvider)
          .submit(
            routeId: widget.routeId,
            body: body,
            rating: _rating,
            imagePaths: [for (final image in _images) image.path],
            replyToReviewId: widget.replyTo?.id,
          );
      _controller.clear();
      setState(() {
        _images.clear();
        _rating = 5;
      });
      widget.onSubmitted();
      ref
        ..invalidate(routeReviewsProvider(widget.routeId))
        ..invalidate(myRouteReviewsProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.replyTo == null
                ? 'Отзыв отправлен на модерацию'
                : 'Ответ отправлен на модерацию',
          ),
        ),
      );
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить отзыв')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final used = _controller.text.characters.length;
    return Container(
      key: _composerKey,
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E4E6)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.replyTo != null) ...[
            _ReplyComposerContext(
              review: widget.replyTo!,
              onCancel: widget.onCancelReply,
            ),
            const SizedBox(height: 10),
          ],
          Text(
            widget.replyTo == null ? 'Ваш отзыв:' : 'Ваш ответ:',
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryInk,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              for (var index = 1; index <= 5; index++) ...[
                InkResponse(
                  radius: 22,
                  onTap: () => setState(() => _rating = index),
                  child: Icon(
                    index <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.rating,
                    size: 32,
                  ),
                ),
                if (index != 5) const SizedBox(width: 2),
              ],
              const Spacer(),
              Material(
                color: const Color(0xFFF0F0F1),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Очистить',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _controller.clear();
                    setState(() {
                      _rating = 5;
                      _images.clear();
                    });
                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.primaryInk,
                    size: 23,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              TextField(
                controller: _controller,
                focusNode: widget.focusNode,
                minLines: 4,
                maxLines: 6,
                maxLength: _maxChars,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 14,
                  color: AppColors.primaryInk,
                  height: 1.35,
                ),
                decoration: InputDecoration(
                  hintText: 'Поделитесь впечатлениями о маршруте',
                  hintStyle: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 14,
                    color: AppColors.secondaryInk,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF0F0F0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD9D9DB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD9D9DB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryInk),
                  ),
                  counterText: '',
                  contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 8,
                child: Text(
                  '$used/$_maxChars',
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 12,
                    color: AppColors.secondaryInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_images.isNotEmpty) ...[
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return _SelectedReviewImage(
                    image: _images[index],
                    onRemove: _sending
                        ? null
                        : () => setState(() => _images.removeAt(index)),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _sending || _images.length >= _maxImages
                    ? null
                    : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                label: Text('Фото ${_images.length}/$_maxImages'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryInk,
                  side: const BorderSide(color: Color(0xFFD9D9DB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _sending ? null : _submit,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryInk,
                side: const BorderSide(color: Color(0xFFD9D9DB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(_sending ? 'Отправка…' : 'Отправить'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedReviewImage extends StatelessWidget {
  const _SelectedReviewImage({required this.image, required this.onRemove});

  final XFile image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 82,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(image.path), fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black.withValues(alpha: 0.58),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyComposerContext extends StatelessWidget {
  const _ReplyComposerContext({required this.review, required this.onCancel});

  final RouteReview review;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('review-reply-composer-context'),
      decoration: BoxDecoration(
        color: AppColors.controlSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 3,
              decoration: const BoxDecoration(
                color: AppColors.primaryInk,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ответ для ${review.authorDisplayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 12,
                        height: 1.25,
                        color: AppColors.secondaryInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Отменить ответ',
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewMediaGrid extends StatelessWidget {
  const _ReviewMediaGrid({
    required this.media,
    required this.config,
    required this.onOpen,
  });

  final List<RouteReviewMedia> media;
  final AppConfig config;
  final ValueChanged<RouteReviewMedia> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in media)
              SizedBox(
                width: width,
                height: 108,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Semantics(
                        button: true,
                        label: 'Открыть фото отзыва',
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onOpen(item),
                            child: Image(
                              image: AppImages.imageProvider(
                                resolvedUrl: AppImages.resolveMediaUrl(
                                  config,
                                  item.url,
                                ),
                                assetFallback: AppImages.coastPineTwilight,
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, _) => const ColoredBox(
                                color: AppColors.controlSurface,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.secondaryInk,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PublishedReplyContext extends StatelessWidget {
  const _PublishedReplyContext({required this.reply});

  final RouteReviewReply reply;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('published-review-reply-${reply.reviewId}'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.controlSurface,
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: AppColors.primaryInk, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.authorDisplayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            reply.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 12,
              height: 1.3,
              color: AppColors.secondaryInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewGalleryDialog extends StatefulWidget {
  const _ReviewGalleryDialog({
    required this.media,
    required this.config,
    required this.initialIndex,
  });

  final List<RouteReviewMedia> media;
  final AppConfig config;
  final int initialIndex;

  @override
  State<_ReviewGalleryDialog> createState() => _ReviewGalleryDialogState();
}

class _ReviewGalleryDialogState extends State<_ReviewGalleryDialog> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('review-photo-fullscreen'),
      color: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.media.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) {
              final item = widget.media[index];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image(
                    image: AppImages.imageProvider(
                      resolvedUrl: AppImages.resolveMediaUrl(
                        widget.config,
                        item.url,
                      ),
                      assetFallback: AppImages.coastPineTwilight,
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: IconButton.filled(
                  tooltip: 'Закрыть',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
          if (widget.media.length > 1)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.media.length}',
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewCard extends ConsumerStatefulWidget {
  const _ReviewCard({
    required this.review,
    required this.onReply,
    this.pending = false,
    this.canDelete = false,
    super.key,
  });

  final RouteReview review;
  final VoidCallback onReply;
  final bool pending;
  final bool canDelete;

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final review = widget.review;
    final score = '${review.rating}';
    final avatar = AppImages.resolveMediaUrl(config, review.authorAvatarUrl);
    final media = review.media;
    return Opacity(
      opacity: widget.pending ? 0.72 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDEDEE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.pending)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'На модерации',
                  style: TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryInk,
                  ),
                ),
              ),
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundImage: AppImages.imageProvider(
                    resolvedUrl: avatar,
                    assetFallback: AppImages.travelerPortrait,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.authorDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: AppColors.primaryInk,
                        ),
                      ),
                      Text(
                        review.authorRankTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          color: AppColors.secondaryInk,
                        ),
                      ),
                    ],
                  ),
                ),
                for (var index = 0; index < 5; index++)
                  Icon(
                    index < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: index < review.rating
                        ? AppColors.rating
                        : AppColors.secondaryInk,
                  ),
                const SizedBox(width: 6),
                Text(
                  score,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.primaryInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (review.replyTo case final reply?) ...[
              _PublishedReplyContext(reply: reply),
              const SizedBox(height: 10),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                const bodyStyle = TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: AppColors.secondaryInk,
                );
                final painter = TextPainter(
                  text: const TextSpan(style: bodyStyle),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 4,
                )..text = TextSpan(text: review.body, style: bodyStyle);
                painter.layout(maxWidth: constraints.maxWidth);
                final expandable =
                    painter.didExceedMaxLines || media.length > 2;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSize(
                      duration: AppMotion.emphasized,
                      curve: AppMotion.standard,
                      alignment: Alignment.topCenter,
                      child: Text(
                        review.body,
                        maxLines: _expanded ? null : 4,
                        overflow: _expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: bodyStyle,
                      ),
                    ),
                    if (media.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      AnimatedSize(
                        duration: AppMotion.emphasized,
                        curve: AppMotion.standard,
                        alignment: Alignment.topCenter,
                        child: _ReviewMediaGrid(
                          media: _expanded ? media : media.take(2).toList(),
                          config: config,
                          onOpen: (item) => _openGallery(media, item),
                        ),
                      ),
                    ],
                    if (expandable) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Text(
                          _expanded
                              ? 'Свернуть отзыв'
                              : 'Читать отзыв полностью',
                          style: AppTypography.button.copyWith(
                            fontSize: 13,
                            color: AppColors.primaryInk,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                GestureDetector(
                  onTap: widget.onReply,
                  child: Text(
                    'Ответить',
                    style: AppTypography.button.copyWith(
                      fontSize: 13,
                      color: AppColors.primaryInk,
                    ),
                  ),
                ),
                if (widget.canDelete) ...[
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () => unawaited(_confirmDelete(context, ref)),
                    child: Text(
                      'Удалить',
                      style: AppTypography.button.copyWith(
                        fontSize: 13,
                        color: AppColors.secondaryInk,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openGallery(List<RouteReviewMedia> media, RouteReviewMedia selected) {
    final initialIndex = media.indexWhere((item) => item.id == selected.id);
    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: Colors.black,
        useSafeArea: false,
        builder: (_) => _ReviewGalleryDialog(
          media: media,
          config: ref.read(appConfigProvider),
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить отзыв?'),
          content: const Text(
            'Отзыв исчезнет из списка. Это действие нельзя отменить.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(routeReviewsRepositoryProvider)
          .delete(routeId: widget.review.routeId, reviewId: widget.review.id);
      ref.invalidate(routeReviewsProvider(widget.review.routeId));
      ref.invalidate(myRouteReviewsProvider);
    } on AppFailure catch (failure) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось удалить отзыв')));
    }
  }
}
