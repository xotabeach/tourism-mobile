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

  @override
  void initState() {
    super.initState();
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
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: AppColors.elevatedSurface,
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 7,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: routes.length,
                    onPageChanged: (index) => setState(() => _page = index),
                    itemBuilder: (context, index) {
                      final route = routes[index];
                      return CatalogRoutePreviewHeader(
                        title: route.title,
                        coverUrl: route.coverUrl,
                        rating: route.rating,
                        distanceKm: route.distanceKm,
                        localityLabel: route.localityLabel,
                        tags: route.tags,
                        budgetLabel: route.budgetLabel,
                        difficultyLabel: route.difficultyLabel,
                        onOpen: () => widget.onOpenRoute(route.routeId),
                      );
                    },
                  ),
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
        ),
      ],
    );
  }
}
