import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/core/design/components/collapsing_hero_header.dart';

/// Which page is loading under the hero photo: the two are laid out
/// differently, and a skeleton is only useful in the shape of what replaces
/// it (FRONTEND-71).
enum DetailsSkeletonKind { route, place }

/// The body of a route or place page while it loads, block for block where
/// the real one will be. Shimmers by itself, so it can stand alone under a
/// hero that already shows its photo.
class DetailsHeroBodySkeleton extends StatelessWidget {
  const DetailsHeroBodySkeleton({
    this.kind = DetailsSkeletonKind.route,
    this.ownShimmer = true,
    super.key,
  });

  final DetailsSkeletonKind kind;

  /// False under a shimmer that already covers the hero, so the two sweep
  /// as one.
  final bool ownShimmer;

  @override
  Widget build(BuildContext context) {
    // Cut off at the bottom of whatever room it is given: a short screen
    // shows fewer blocks rather than an overflow.
    final body = SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: kind == DetailsSkeletonKind.route
            ? _routeBlocks()
            : _placeBlocks(),
      ),
    );
    return ownShimmer ? AppShimmer(child: body) : body;
  }

  /// Author row, title, description, the two tabs, chips and facts.
  static List<Widget> _routeBlocks() => const [
    Row(
      children: [
        AppSkeleton(width: 48, height: 48, shape: BoxShape.circle),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(width: 168, height: 16, borderRadius: 6),
              SizedBox(height: 6),
              AppSkeleton(width: 64, height: 12, borderRadius: 6),
            ],
          ),
        ),
        AppSkeleton(width: 48, height: 48, shape: BoxShape.circle),
      ],
    ),
    _Hairline(),
    AppSkeleton(width: 290, height: 24, borderRadius: 8),
    SizedBox(height: 12),
    _TextLines(count: 3),
    SizedBox(height: 16),
    Row(
      children: [
        Expanded(
          child: AppSkeleton(
            width: double.infinity,
            height: 38,
            borderRadius: 8,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: AppSkeleton(
            width: double.infinity,
            height: 38,
            borderRadius: 8,
          ),
        ),
      ],
    ),
    _Hairline(),
    _Chips(widths: [64, 70]),
    SizedBox(height: 18),
    _FactLines(widths: [118, 150, 134, 128]),
  ];

  /// Title, chips, description, then the related routes.
  static List<Widget> _placeBlocks() => const [
    AppSkeleton(width: 250, height: 26, borderRadius: 8),
    SizedBox(height: 12),
    _Chips(widths: [86, 70, 62]),
    SizedBox(height: 14),
    _TextLines(count: 4),
    _Hairline(),
    AppSkeleton(width: 220, height: 20, borderRadius: 7),
    SizedBox(height: 12),
    AppSkeleton(width: double.infinity, height: 48, borderRadius: 12),
    SizedBox(height: 6),
    AppSkeleton(width: double.infinity, height: 48, borderRadius: 12),
  ];
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Divider(height: 1, thickness: 1, color: AppColors.hairline),
  );
}

/// Running text: full lines and a shorter last one.
class _TextLines extends StatelessWidget {
  const _TextLines({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) const SizedBox(height: 7),
        FractionallySizedBox(
          widthFactor: i == count - 1 ? 0.62 : 1,
          child: const AppSkeleton(
            width: double.infinity,
            height: 12,
            borderRadius: 6,
          ),
        ),
      ],
    ],
  );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.widths});

  final List<double> widths;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    children: [
      for (final width in widths)
        AppSkeleton(width: width, height: 26, borderRadius: 13),
    ],
  );
}

/// «Сложность: 2/5» and the like: an icon and a short line each.
class _FactLines extends StatelessWidget {
  const _FactLines({required this.widths});

  final List<double> widths;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final width in widths)
        SizedBox(
          height: 28,
          child: Row(
            children: [
              const AppSkeleton(width: 17, height: 17, shape: BoxShape.circle),
              const SizedBox(width: 8),
              AppSkeleton(width: width, height: 13, borderRadius: 6),
            ],
          ),
        ),
    ],
  );
}

const _sheetOverlap = 24.0;

class DetailsHeroLoadingView extends StatelessWidget {
  const DetailsHeroLoadingView({
    this.showBack = true,
    this.onBack,
    this.kind = DetailsSkeletonKind.route,
    super.key,
  });

  final bool showBack;
  final DetailsSkeletonKind kind;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        AppShimmer(
          child: ColoredBox(
            color: AppColors.elevatedSurface,
            child: Column(
              children: [
                AppSkeleton(
                  width: double.infinity,
                  height: topInset + 360,
                  borderRadius: 0,
                ),
                Expanded(
                  // The white sheet rides over the photo, as on the page.
                  child: Transform.translate(
                    offset: const Offset(0, -_sheetOverlap),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AppColors.elevatedSurface,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(_sheetOverlap),
                        ),
                      ),
                      child: DetailsHeroBodySkeleton(
                        kind: kind,
                        ownShimmer: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showBack)
          Positioned(
            top: topInset + 8,
            left: 14,
            child: CollapsingHeroAction(
              key: const ValueKey('details-hero-loading-back'),
              semanticLabel: 'Назад',
              icon: Icons.arrow_back_rounded,
              onPressed: onBack ?? () {},
            ),
          ),
      ],
    );
  }
}
