import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_favorite_icon.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/design/components/audio_guide_card.dart';
import 'package:tourism_mobile/core/design/components/collapsing_hero_header.dart';
import 'package:tourism_mobile/core/design/components/details_hero_loading_view.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/places/presentation/place_reviews_section.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart'
    show difficultyLabel;
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
      // White, not pageSurface: everything on this screen is photo-then-white
      // sheet, no gray anywhere by design (matches RouteDetailsScreen). A
      // gray Scaffold behind it means any seam — sub-pixel rounding, an
      // overscroll bounce, a dropped frame — shows gray instead of just
      // disappearing into the sheet.
      backgroundColor: AppColors.elevatedSurface,
      body: placeAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        data: (place) => _PlaceDetailsBody(place: place),
        loading: () => DetailsHeroLoadingView(onBack: () => context.pop()),
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
    final rawHeroHeight = (MediaQuery.sizeOf(context).height * 0.57).clamp(
      430.0,
      590.0,
    );
    // Round to a whole physical pixel. A fractional sliver boundary put the
    // header/sheet seam between two sub-pixels instead of on one, leaving a
    // hairline gap (the page's gray background showing through) even at
    // rest, before any scrolling. RouteCollapsingHeader never hit this
    // because its expandedHeight (320) is already a clean whole number.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final heroHeight = (rawHeroHeight * dpr).round() / dpr;
    final config = ref.watch(appConfigProvider);

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
            onMap: () => _showPlaceMap(context, place, config),
          ),
          SliverToBoxAdapter(child: _PlaceInformationSheet(place: place)),
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
      // White (not pageSurface) — the photo crossfades into this color as
      // the header collapses, and the info sheet right below is white too
      // (see the lip in the builder below), so this reads as "the sheet
      // rising up" instead of "the photo fading to a flat gray slab".
      background: RepaintBoundary(
        child: PageView.builder(
          itemCount: images.length,
          onPageChanged: (value) => setState(() => _page = value),
          itemBuilder: (_, index) => AppImages.coverImage(
            config: config,
            coverImageUrl: images[index],
            fallbackSeed: '${widget.place.slug}-$index',
          ),
        ),
      ),
      builder: (context, t, shrinkOffset, currentExtent) {
        const spec = HeroCollapseSpec.place;
        final expanded = spec.expandedVisibility(t);
        final collapsed = spec.collapsedVisibility(t);
        return Stack(
          fit: StackFit.expand,
          children: [
            // No always-on darkening gradient here (unlike an earlier
            // version): it painted on every frame regardless of scroll
            // progress, so it tinted the fully-collapsed white bar and the
            // sheet lip too — a visible seam where the tinted lip met the
            // untinted info sheet below, and a shadow-like band across the
            // "pinned" bar. Icon contrast comes from each control's own
            // glass/black fill (matches route_collapsing_header.dart, which
            // has never had a full-bleed gradient).
            CollapseLayer(
              visibility: expanded,
              scale: spec.scale,
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
                      // Sit above the sheet lip so dots stay on the photo.
                      bottom: 36,
                      child: _PageDots(count: images.length, selected: _page),
                    ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: images.length > 1 ? 56 : 38,
                    child: SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: widget.onMap,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.48),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.capsule,
                            ),
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
            // Rounded sheet lip painted with the header so the body sheet
            // below can stay flat (see route_collapsing_header.dart for the
            // pattern this mirrors) — a Transform-translated body radius
            // gets clipped at the sliver boundary instead of showing.
            //
            // It is the top edge of the sheet, not an overlay: it must never
            // fade or scale out (that read as a white bar detaching mid
            // scroll). Only the corner radius eases to 0 as the hero turns
            // into the collapsed bar, which is white anyway by then.
            CollapsingSheetLip(progress: t),
            CollapseLayer(
              visibility: collapsed,
              scale: spec.scale,
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
      decoration: const BoxDecoration(color: AppColors.elevatedSurface),
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
          if (place.categories.isNotEmpty ||
              place.difficulty != null ||
              place.isPaid) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final category in place.categories.take(3))
                  _PlaceInfoTag(label: category.name),
                if (place.difficulty != null)
                  _PlaceInfoTag(label: difficultyLabel(place.difficulty)),
                if (place.isPaid) const _PlaceInfoTag(label: 'Платно'),
              ],
            ),
          ],
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
          AudioGuideCard(
            title: place.name,
            image: cover,
            onPlay: () {
              showAppNotice(context, 'Аудиогид появится позже');
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 1, color: AppColors.hairline),
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
              child: Divider(
                height: 1,
                thickness: 1,
                color: AppColors.hairline,
              ),
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
            child: Divider(height: 1, thickness: 1, color: AppColors.hairline),
          ),
          PlaceReviewsSection(placeId: place.id),
        ],
      ),
    );
  }
}

class _PlaceInfoTag extends StatelessWidget {
  const _PlaceInfoTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.controlSurface,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryInk,
          ),
        ),
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
      borderRadius: BorderRadius.circular(AppRadii.tile),
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
              borderRadius: BorderRadius.circular(AppRadii.tile),
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
                borderRadius: BorderRadius.circular(AppRadii.tile),
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

void _showPlaceMap(BuildContext context, PlaceDetail place, AppConfig config) {
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.elevatedSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.modal),
        ),
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
                borderRadius: BorderRadius.circular(AppRadii.capsule),
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
                  mapImage: _staticMapImage(config, place.staticMapUrl),
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

ImageProvider<Object>? _staticMapImage(AppConfig config, String? value) {
  final resolved = AppImages.resolveMediaUrl(config, value);
  if (resolved == null) return null;
  return AppImages.imageProvider(resolvedUrl: resolved);
}

void _showMessage(BuildContext context, String message) {
  showAppNotice(context, message);
}
