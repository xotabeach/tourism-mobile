import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_builder_design_tokens.dart';
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

  static const double _peekGap = 10;

  @override
  void initState() {
    super.initState();
    // Slight peek of the neighboring card (instead of a full-bleed page) so
    // there's visible spacing between routes while swiping, not a hard cut.
    _pageController = PageController(viewportFraction: 0.94);
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
                  final photoHeight =
                      constraints.maxWidth * 0.94 * 7 / 16;
                  return SizedBox(
                    height: photoHeight + 226,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: routes.length,
                      onPageChanged: (index) => setState(() => _page = index),
                      itemBuilder: (context, index) {
                        final route = routes[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _peekGap / 2,
                          ),
                          child: _CatalogRoutePage(
                            route: route,
                            onOpen: () => widget.onOpenRoute(route.routeId),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              if (routes.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < routes.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: i == _page ? 8 : 6,
                          height: i == _page ? 8 : 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _page
                                ? RouteBuilderDesignTokens.primaryBlue
                                : RouteBuilderDesignTokens.borderGray,
                          ),
                        ),
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
        ? '${route.distanceKm!.toStringAsFixed(1)} км'
        : null;
    final durationLabel = route.durationMinutes > 0
        ? formatRouteDuration(route.durationMinutes)
        : null;
    final stopsLabel = route.stopsCount > 0 ? '${route.stopsCount}' : null;
    // Design export wraps the whole preview (photo + tags + params) in a
    // hairline-bordered rounded card inside the bubble.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 7,
            child: CatalogRoutePreviewHeader(
              title: route.title,
              coverUrl: route.coverUrl,
              rating: route.rating,
              distanceKm: route.distanceKm,
              localityLabel: route.localityLabel,
              onOpen: onOpen,
            ),
          ),
          if (route.tags.isNotEmpty ||
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
                    if (route.tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in route.tags)
                            RoutePreviewTagChip(label: tag),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.hairline,
                      ),
                      const SizedBox(height: 12),
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
