import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/collapsing_hero_header.dart';

/// Collapsing media hero for route details (scroll shrink + PageView photos).
class RouteCollapsingHeader extends StatefulWidget {
  const RouteCollapsingHeader({
    required this.images,
    required this.title,
    required this.authorName,
    required this.authorSubtitle,
    required this.avatar,
    required this.isFavorite,
    required this.onBack,
    required this.onToggleFavorite,
    required this.onShare,
    required this.onDownload,
    required this.onAuthorTap,
    this.heroTag,
    super.key,
  });

  static const double expandedHeight = 320;
  static const double collapsedBarHeight = 56;

  final List<ImageProvider> images;
  final String title;
  final String authorName;
  final String authorSubtitle;
  final ImageProvider avatar;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback? onAuthorTap;
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

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final collapsedHeight = topInset + RouteCollapsingHeader.collapsedBarHeight;

    return CollapsingHeroSliver(
      expandedHeight: RouteCollapsingHeader.expandedHeight,
      collapsedHeight: collapsedHeight,
      background: Stack(
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
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x59000000),
                  Color(0x00000000),
                  Color(0x99000000),
                ],
                stops: [0, 0.38, 1],
              ),
            ),
          ),
        ],
      ),
      builder: (context, t, shrinkOffset, currentExtent) {
        final expandedVis = CollapseProgress.fadeOut(t, start: 0.0, end: 0.55);
        final collapsedVis = CollapseProgress.fadeIn(t, start: 0.4, end: 0.9);
        final compactTitle = '${widget.authorName}: ${widget.title}';

        return Stack(
          fit: StackFit.expand,
          children: [
            // Expanded chrome: actions + author strip + dots.
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
                    bottom: 72,
                    child: _PageDots(
                      count: widget.images.length,
                      active: _page,
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _ExpandedAuthorStrip(
                      name: widget.authorName,
                      subtitle: widget.authorSubtitle,
                      avatar: widget.avatar,
                      onAuthorTap: widget.onAuthorTap,
                    ),
                  ),
                ],
              ),
            ),
            // Collapsed chrome: back + compact identity + menu.
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
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.onAuthorTap,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundImage: widget.avatar,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    compactTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.settingsRowTitle
                                        .copyWith(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
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

class _ExpandedAuthorStrip extends StatelessWidget {
  const _ExpandedAuthorStrip({
    required this.name,
    required this.subtitle,
    required this.avatar,
    this.onAuthorTap,
  });

  final String name;
  final String subtitle;
  final ImageProvider avatar;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAuthorTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(radius: 22, backgroundImage: avatar),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                    color: Colors.white.withValues(alpha: 0.88),
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
