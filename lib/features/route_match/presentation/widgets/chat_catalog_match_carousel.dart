import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/widgets/chat_route_proposal_card.dart';

/// Horizontal carousel of catalog route previews (design-spec screen 2).
class ChatCatalogMatchCarousel extends StatefulWidget {
  const ChatCatalogMatchCarousel({
    required this.routes,
    required this.onOpenRoute,
    super.key,
  });

  final List<CatalogRouteItem> routes;
  final ValueChanged<String> onOpenRoute;

  @override
  State<ChatCatalogMatchCarousel> createState() =>
      _ChatCatalogMatchCarouselState();
}

class _ChatCatalogMatchCarouselState extends State<ChatCatalogMatchCarousel> {
  late final PageController _pageController;
  int _page = 0;

  /// Photo proportion of the design (card width to photo height).
  static const double _photoAspect = 3.1;

  /// Space between two cards while one is being swiped away. At rest a card
  /// still fills the bubble's content width exactly (FRONTEND-41: pages used
  /// to butt against each other mid-swipe and read as one torn card).
  static const double _pageGap = 12;

  @override
  void initState() {
    super.initState();
    // Full width of the bubble's content: the card lines up with the text
    // and the buttons around it (design, FRONTEND-12). The old 94% page with
    // a peek of the next card sat off the bubble's grid.
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routes = widget.routes;
    if (routes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: Column(
            children: [
              // Page height = photo (16:7, scales with actual width) +
              // room for the tags row and up to 6 param rows below it
              // (design-spec screen 2, plus duration/stops) — generous
              // enough for the longest realistic combination without
              // overflow at any bubble width.
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final photoHeight = width / _photoAspect;
                  // Each page is one gap wider than the bubble and keeps half
                  // a gap on either side of its card; the outer clip hides
                  // those halves at rest and shows a full gap mid-swipe.
                  // Body (measured): padding, two rows of tags, the divider and the
                  // four param rows of the mockup; the match line only when
                  // a route carries one, so the card ends under its content.
                  final hasMatch = routes.any(
                    (route) => route.matchPercent != null,
                  );
                  return SizedBox(
                    height: photoHeight + 180 + (hasMatch ? 30 : 0),
                    child: ClipRect(
                      child: OverflowBox(
                        minWidth: width + _pageGap,
                        maxWidth: width + _pageGap,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: routes.length,
                          onPageChanged: (index) =>
                              setState(() => _page = index),
                          itemBuilder: (context, index) {
                            final route = routes[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: _pageGap / 2,
                              ),
                              child: _CatalogRoutePage(
                                route: route,
                                onOpen: () => widget.onOpenRoute(route.routeId),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (routes.length > 1)
                Padding(
                  // Mockup: 13 pt from the dots to the first button, with
                  // the bubble's own 10 pt after the carousel.
                  padding: const EdgeInsets.only(top: 8, bottom: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < routes.length; i++) ...[
                        if (i > 0) const SizedBox(width: chatPageDotGap),
                        ChatPageDot(index: i, current: _page),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One carousel page: photo header (title/rating/locality/distance overlaid
/// on the image), then tags + param rows on white background below it —
/// matches design-spec screen 2 exactly (tags are not overlaid on the photo).
class _CatalogRoutePage extends StatelessWidget {
  const _CatalogRoutePage({required this.route, required this.onOpen});

  final CatalogRouteItem route;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final distanceLabel = route.distanceKm != null
        ? '${route.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} км'
        : null;
    // The chat card shows the design's four rows (budget, difficulty, route,
    // distance); time and stops are on the route's own screen.
    const String? durationLabel = null;
    const String? stopsLabel = null;
    // Design export wraps the whole preview (photo + tags + params) in a
    // hairline-bordered rounded card inside the bubble.
    return Container(
      // Mockup: #D1D1D1 hairline, 6 pt corners (measured on the export).
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        border: Border.all(color: const Color(0xFFD1D1D1)),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: _ChatCatalogMatchCarouselState._photoAspect,
            child: CatalogRoutePreviewHeader(
              title: route.title,
              coverUrl: route.coverUrl,
              rating: route.rating,
              distanceKm: route.distanceKm,
              localityLabel: route.localityLabel,
              onOpen: onOpen,
            ),
          ),
          if (route.matchPercent != null ||
              route.tags.isNotEmpty ||
              route.budgetLabel != null ||
              route.difficultyLabel != null ||
              route.localityLabel != null ||
              distanceLabel != null ||
              durationLabel != null ||
              stopsLabel != null)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (route.matchPercent != null) ...[
                      _MatchLine(
                        percent: route.matchPercent!,
                        note: route.mainMismatch,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (route.tags.isNotEmpty) ...[
                      Wrap(
                        spacing: routePreviewTagGap,
                        runSpacing: routePreviewTagGap,
                        children: [
                          for (final tag in route.tags)
                            RoutePreviewTagChip(label: tag),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.hairline,
                      ),
                      const SizedBox(height: 8),
                    ],
                    RouteParamsBlock(
                      budgetLabel: route.budgetLabel,
                      difficultyLabel: route.difficultyLabel,
                      localityLabel: route.localityLabel,
                      distanceLabel: distanceLabel,
                      durationLabel: durationLabel,
                      stopsLabel: stopsLabel,
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

/// «Подходит на 75%» plus the one main reason it is not a full match. Shown
/// only when the message carried a percent; older messages have none.
class _MatchLine extends StatelessWidget {
  const _MatchLine({required this.percent, this.note});

  final int percent;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final text = note == null
        ? 'Подходит на $percent%'
        : 'Подходит на $percent% · $note';
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.routeMetadata.copyWith(
        fontSize: 14,
        color: AppColors.accentBlue,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
