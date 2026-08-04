import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/collapsing_hero_header.dart';

/// Collapsing media hero for route details.
///
/// Scroll shrinks the hero; a tap toggles gallery expansion (taller media).
/// Author row lives in the body sheet — not on the photo — to match design.
class RouteCollapsingHeader extends StatefulWidget {
  const RouteCollapsingHeader({
    required this.images,
    required this.title,
    required this.isFavorite,
    required this.onBack,
    required this.onToggleFavorite,
    required this.onShare,
    required this.onDownload,
    this.expansionProgress = 0,
    this.onToggleGallery,
    this.heroTag,
    super.key,
  });

  /// Resting (non–gallery-expanded) media height.
  static const double expandedHeight = 320;
  static const double collapsedBarHeight = 56;
  static const double galleryHeightFactor = 0.66;

  final List<ImageProvider> images;
  final String title;
  final bool isFavorite;
  final double expansionProgress;
  final VoidCallback? onToggleGallery;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final Object? heroTag;

  @override
  State<RouteCollapsingHeader> createState() => _RouteCollapsingHeaderState();
}

class _RouteCollapsingHeaderState extends State<RouteCollapsingHeader> {
  final _pageController = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showActionsMenu() {
    final top = MediaQuery.paddingOf(context).top;
    unawaited(() async {
      final value = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(100, top + 8, 12, 0),
        items: [
          PopupMenuItem(
            value: 'favorite',
            child: Text(
              widget.isFavorite ? 'Удалить из избранного' : 'В избранное',
            ),
          ),
          const PopupMenuItem(value: 'share', child: Text('Поделиться')),
          const PopupMenuItem(value: 'download', child: Text('Скачать офлайн')),
        ],
      );
      switch (value) {
        case 'favorite':
          widget.onToggleFavorite();
        case 'share':
          widget.onShare();
        case 'download':
          widget.onDownload();
      }
    }());
  }

  double _mediaMaxExtent(BuildContext context) {
    final galleryMax =
        MediaQuery.sizeOf(context).height *
        RouteCollapsingHeader.galleryHeightFactor;
    final progress = widget.expansionProgress.clamp(0.0, 1.0);
    return RouteCollapsingHeader.expandedHeight +
        (galleryMax - RouteCollapsingHeader.expandedHeight) * progress;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final collapsedHeight = topInset + RouteCollapsingHeader.collapsedBarHeight;
    final mediaMax = _mediaMaxExtent(context);
    final galleryOpen = widget.expansionProgress > 0.5;

    return CollapsingHeroSliver(
      pinned: true,
      expandedHeight: mediaMax,
      collapsedHeight: collapsedHeight,
      // GestureDetector parents PageView: tap toggles gallery, horizontal
      // drag still reaches the pager (same hit-test path / gesture arena).
      background: Semantics(
        label: galleryOpen
            ? 'Галерея маршрута раскрыта'
            : 'Обложка маршрута, нажмите, чтобы раскрыть галерею',
        button: true,
        onTap: widget.onToggleGallery,
        child: GestureDetector(
          onTap: widget.onToggleGallery,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (value) => setState(() => _page = value),
                itemCount: widget.images.length,
                itemBuilder: (context, index) {
                  final image = Image(
                    image: widget.images[index],
                    fit: BoxFit.cover,
                  );
                  if (index == 0 && widget.heroTag != null) {
                    return Hero(
                      tag: widget.heroTag!,
                      transitionOnUserGestures: true,
                      child: image,
                    );
                  }
                  return image;
                },
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x59000000),
                        Color(0x00000000),
                        Color(0x4D000000),
                      ],
                      stops: [0, 0.38, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      builder: (context, t, shrinkOffset, currentExtent) {
        final expandedVis = CollapseProgress.fadeOut(t, start: 0.0, end: 0.55);
        final collapsedVis = CollapseProgress.fadeIn(t, start: 0.4, end: 0.9);

        // Keep overlays sparse: empty regions must miss hit tests so the
        // background PageView can receive horizontal drags.
        return Stack(
          fit: StackFit.expand,
          children: [
            CollapseLayer(
              visibility: expandedVis,
              scaleAlignment: Alignment.topCenter,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: topInset + 8,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        CollapsingHeroAction(
                          semanticLabel: 'Назад',
                          icon: Icons.arrow_back_rounded,
                          onPressed: widget.onBack,
                        ),
                        const Spacer(),
                        CollapsingHeroAction(
                          semanticLabel: widget.isFavorite
                              ? 'Удалить из избранного'
                              : 'Добавить в избранное',
                          icon: widget.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          onPressed: widget.onToggleFavorite,
                        ),
                        const SizedBox(width: 8),
                        CollapsingHeroAction(
                          semanticLabel: 'Поделиться',
                          icon: Icons.ios_share_rounded,
                          onPressed: widget.onShare,
                        ),
                        const SizedBox(width: 8),
                        CollapsingHeroAction(
                          semanticLabel: 'Скачать офлайн',
                          iconAsset: AppIconography.download,
                          onPressed: widget.onDownload,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    // Sit above the sheet lip so dots stay on the photo.
                    bottom: 36,
                    child: IgnorePointer(
                      child: _PageDots(
                        count: widget.images.length,
                        active: _page,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Rounded sheet lip painted with the header so body content is
            // not covered by the pinned media (author stays in the body).
            CollapseLayer(
              visibility: expandedVis,
              child: const IgnorePointer(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: 24,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.elevatedSurface,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            CollapseLayer(
              visibility: collapsedVis,
              scaleAlignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.only(top: topInset),
                child: SizedBox(
                  height: RouteCollapsingHeader.collapsedBarHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        CollapsingHeroAction(
                          semanticLabel: 'Назад',
                          icon: Icons.arrow_back_rounded,
                          onPhoto: false,
                          onPressed: widget.onBack,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTypography.settingsRowTitle.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        CollapsingHeroAction(
                          semanticLabel: 'Меню маршрута',
                          icon: Icons.more_horiz_rounded,
                          onPhoto: false,
                          onPressed: _showActionsMenu,
                        ),
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

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    if (count < 2) {
      return const SizedBox(height: 10);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: index == active ? 10 : 8,
              height: index == active ? 10 : 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: index == active ? 1 : 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
