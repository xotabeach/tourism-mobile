import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_favorite_icon.dart';
import 'package:tourism_mobile/core/design/components/collapsing_hero_header.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/places/presentation/place_reviews_section.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_preview.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class PlaceDetailsScreen extends ConsumerWidget {
  const PlaceDetailsScreen({required this.placeId, super.key});

  static const routePath = '/places/:id';
  static const routeSegment = ':id';

  final String placeId;

  static Future<T?> openFromRoute<T extends Object?>(
    BuildContext context, {
    required String routeId,
    required String placeId,
  }) {
    return context.push<T>('/routes/$routeId/place/$placeId');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeAsync = ref.watch(placeDetailProvider(placeId));

    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      body: placeAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        data: (place) => _PlaceDetailsBody(place: place),
        loading: () => const _PlaceDetailsLoading(),
        error: (_, _) => AppAsyncErrorView(
          onRetry: () => ref.invalidate(placeDetailProvider(placeId)),
        ),
      ),
    );
  }
}

class _PlaceDetailsBody extends ConsumerWidget {
  const _PlaceDetailsBody({required this.place});

  final PlaceDetail place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(
      favoritesProvider.select((state) => state.placeIds.contains(place.id)),
    );
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.57).clamp(
      430.0,
      590.0,
    );

    Future<void> toggleFavorite() async {
      try {
        await ref.read(favoritesProvider.notifier).togglePlace(place.id);
      } on Object {
        if (!context.mounted) return;
        _showMessage(context, 'Не удалось обновить избранное');
      }
    }

    Future<void> sharePlace() async {
      final address = place.address?.trim();
      final value = [
        place.name,
        if (address != null && address.isNotEmpty) address,
        '${place.lat.toStringAsFixed(6)}, ${place.lng.toStringAsFixed(6)}',
      ].join('\n');
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) {
        _showMessage(context, 'Данные места скопированы');
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(placeDetailProvider(place.id))
          ..invalidate(routesForPlaceProvider(place.id));
        await ref.read(placeDetailProvider(place.id).future);
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          _PlacePhotoHeader(
            place: place,
            expandedHeight: heroHeight,
            isFavorite: isFavorite,
            onBack: context.pop,
            onFavorite: () => unawaited(toggleFavorite()),
            onShare: () => unawaited(sharePlace()),
            onMap: () => _showPlaceMap(context, place),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -18),
              child: _PlaceInformationSheet(place: place),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacePhotoHeader extends ConsumerStatefulWidget {
  const _PlacePhotoHeader({
    required this.place,
    required this.expandedHeight,
    required this.isFavorite,
    required this.onBack,
    required this.onFavorite,
    required this.onShare,
    required this.onMap,
  });

  final PlaceDetail place;
  final double expandedHeight;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onMap;

  @override
  ConsumerState<_PlacePhotoHeader> createState() => _PlacePhotoHeaderState();
}

class _PlacePhotoHeaderState extends ConsumerState<_PlacePhotoHeader> {
  var _page = 0;

  List<String?> get _images {
    final result = <String?>[];
    void add(String? value) {
      if (value != null && value.isNotEmpty && !result.contains(value)) {
        result.add(value);
      }
    }

    add(widget.place.coverImageUrl);
    for (final image in widget.place.imageUrls) {
      add(image);
    }
    if (result.isEmpty) result.add(null);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final config = ref.watch(appConfigProvider);
    final images = _images;

    return CollapsingHeroSliver(
      expandedHeight: widget.expandedHeight,
      collapsedHeight: topInset + 56,
      collapsedColor: AppColors.pageSurface,
      background: PageView.builder(
        itemCount: images.length,
        onPageChanged: (value) => setState(() => _page = value),
        itemBuilder: (_, index) => AppImages.coverImage(
          config: config,
          coverImageUrl: images[index],
          fallbackSeed: '${widget.place.slug}-$index',
        ),
      ),
      builder: (context, t, shrinkOffset, currentExtent) {
        final expanded = CollapseProgress.fadeOut(t, start: 0.02, end: 0.64);
        final collapsed = CollapseProgress.fadeIn(t, start: 0.55, end: 0.92);
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.30),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.24),
                    ],
                    stops: const [0, 0.42, 1],
                  ),
                ),
              ),
            ),
            CollapseLayer(
              visibility: expanded,
              scale: false,
              child: Stack(
                children: [
                  Positioned(
                    top: topInset + 8,
                    left: 14,
                    right: 14,
                    child: Row(
                      children: [
                        CollapsingHeroAction(
                          key: const ValueKey('place-details-back'),
                          semanticLabel: 'Назад',
                          icon: Icons.arrow_back_rounded,
                          onPressed: widget.onBack,
                        ),
                        const Spacer(),
                        CollapsingHeroAction(
                          semanticLabel: 'Поделиться',
                          icon: Icons.ios_share_rounded,
                          onPressed: widget.onShare,
                        ),
                        const SizedBox(width: 8),
                        CollapsingHeroAction(
                          semanticLabel: widget.isFavorite
                              ? 'Удалить из избранного'
                              : 'Добавить в избранное',
                          iconWidget: AppFavoriteIcon(
                            selected: widget.isFavorite,
                            size: 22,
                          ),
                          onPressed: widget.onFavorite,
                        ),
                      ],
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 22,
                      child: _PageDots(count: images.length, selected: _page),
                    ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: images.length > 1 ? 42 : 24,
                    child: SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: widget.onMap,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.48),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.38),
                            ),
                          ),
                        ),
                        child: const Text('Посмотреть на карте'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            CollapseLayer(
              visibility: collapsed,
              child: Padding(
                padding: EdgeInsets.only(top: topInset),
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      CollapsingHeroAction(
                        semanticLabel: 'Назад',
                        icon: Icons.arrow_back_rounded,
                        onPhoto: false,
                        onPressed: widget.onBack,
                      ),
                      Expanded(
                        child: Text(
                          widget.place.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.settingsRowTitle.copyWith(
                            fontSize: 16,
                          ),
                        ),
                      ),
                      CollapsingHeroAction(
                        semanticLabel: widget.isFavorite
                            ? 'Удалить из избранного'
                            : 'Добавить в избранное',
                        iconWidget: AppFavoriteIcon(
                          selected: widget.isFavorite,
                          size: 22,
                        ),
                        onPhoto: false,
                        onPressed: widget.onFavorite,
                      ),
                      const SizedBox(width: 8),
                    ],
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

class _PlaceInformationSheet extends ConsumerWidget {
  const _PlaceInformationSheet({required this.place});

  final PlaceDetail place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final description = place.description?.trim().isNotEmpty == true
        ? place.description!.trim()
        : place.shortDescription?.trim();
    final routes = ref.watch(routesForPlaceProvider(place.id));
    final config = ref.watch(appConfigProvider);
    final cover = AppImages.imageProvider(
      resolvedUrl: AppImages.resolveMediaUrl(config, place.coverImageUrl),
      assetFallback: AppImages.coastPineTwilight,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        112 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            place.name,
            style: AppTypography.routeTitle.copyWith(
              fontSize: 24,
              height: 1.14,
              color: AppColors.primaryInk,
            ),
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.42,
                color: AppColors.secondaryInk,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _PlaceAudioGuideCard(
            title: place.name,
            image: cover,
            onPlay: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('Аудиогид появится позже')),
                );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F1)),
          ),
          const Text(
            'Маршруты с этим местом:',
            style: TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: AppColors.primaryInk,
            ),
          ),
          const SizedBox(height: 10),
          routes.when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => const _RelatedRoutesLoading(),
            error: (_, _) => _InlineError(
              label: 'Не удалось загрузить маршруты',
              onRetry: () => ref.invalidate(routesForPlaceProvider(place.id)),
            ),
            data: (page) => _RelatedRoutesCarousel(routes: page.items),
          ),
          if (place.safetyWarnings.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F1)),
            ),
            const Text(
              'Перед посещением:',
              style: TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: AppColors.primaryInk,
              ),
            ),
            const SizedBox(height: 8),
            for (final warning in place.safetyWarnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.secondaryInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F1)),
          ),
          PlaceReviewsSection(placeId: place.id),
        ],
      ),
    );
  }
}

class _PlaceAudioGuideCard extends StatelessWidget {
  const _PlaceAudioGuideCard({
    required this.title,
    required this.image,
    required this.onPlay,
  });

  final String title;
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
                const Text(
                  'КрымТрип',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
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
            '48м 17с',
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

class _RelatedRoutesCarousel extends StatefulWidget {
  const _RelatedRoutesCarousel({required this.routes});

  final List<RouteSummary> routes;

  @override
  State<_RelatedRoutesCarousel> createState() => _RelatedRoutesCarouselState();
}

class _RelatedRoutesCarouselState extends State<_RelatedRoutesCarousel> {
  static const _pageSize = 3;
  var _page = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.routes.isEmpty) {
      return const SizedBox(
        height: 72,
        child: Center(child: Text('Пока нет маршрутов с этой точкой')),
      );
    }
    final pageCount = (widget.routes.length / _pageSize).ceil();
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            itemCount: pageCount,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, pageIndex) {
              final start = pageIndex * _pageSize;
              final end = (start + _pageSize).clamp(0, widget.routes.length);
              return Column(
                children: [
                  for (final route in widget.routes.sublist(start, end))
                    _RelatedRouteRow(route: route),
                ],
              );
            },
          ),
        ),
        if (pageCount > 1)
          _PageDots(count: pageCount, selected: _page, dark: true),
      ],
    );
  }
}

class _RelatedRouteRow extends ConsumerWidget {
  const _RelatedRouteRow({required this.route});

  final RouteSummary route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.pushNamed(
        AppRouteNames.routeDetails,
        pathParameters: {'id': route.id},
        extra: route,
      ),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 42,
                child: AppImages.coverImage(
                  config: config,
                  coverImageUrl: route.coverImageUrl,
                  fallbackSeed: route.slug,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.name,
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
                  const SizedBox(height: 2),
                  Text(
                    route.authorLabel ?? 'КрымТрип редакция',
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
            const Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: AppColors.secondaryInk,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.selected,
    this.dark = false,
  });

  final int count;
  final int selected;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count.clamp(0, 7); i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: i == selected ? 8 : 6,
            height: i == selected ? 8 : 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? (i == selected
                        ? AppColors.primaryInk
                        : AppColors.controlSurface)
                  : Colors.white.withValues(alpha: i == selected ? 1 : 0.45),
            ),
          ),
      ],
    );
  }
}

class _RelatedRoutesLoading extends StatelessWidget {
  const _RelatedRoutesLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.controlSurface,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.label, required this.onRetry});

  final String label;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(label),
        ),
      ),
    );
  }
}

class _PlaceDetailsLoading extends StatelessWidget {
  const _PlaceDetailsLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(flex: 6, child: Container(color: AppColors.controlSurface)),
        Expanded(
          flex: 4,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.elevatedSurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 210,
                  height: 24,
                  color: AppColors.controlSurface,
                ),
                const SizedBox(height: 12),
                Container(height: 90, color: AppColors.controlSurface),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void _showPlaceMap(BuildContext context, PlaceDetail place) {
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.elevatedSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.controlSurface,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(place.name, style: AppTypography.sectionTitle),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => RouteMapPreview(
                  height: constraints.maxHeight,
                  selectedIndex: 0,
                  onPinTap: (_) {},
                  footerLabel:
                      '${place.lat.toStringAsFixed(5)}, '
                      '${place.lng.toStringAsFixed(5)}',
                  stops: [
                    RouteStop(
                      id: place.id,
                      position: 1,
                      placeId: place.id,
                      placeName: place.name,
                      placeSlug: place.slug,
                      lat: place.lat,
                      lng: place.lng,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: '${place.lat}, ${place.lng}'),
                    );
                    if (sheetContext.mounted) {
                      _showMessage(sheetContext, 'Координаты скопированы');
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Скопировать координаты'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
