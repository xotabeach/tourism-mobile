import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/core/design/components/collapsing_hero_header.dart';

class DetailsHeroBodySkeleton extends StatelessWidget {
  const DetailsHeroBodySkeleton({super.key});

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

class DetailsHeroLoadingView extends StatelessWidget {
  const DetailsHeroLoadingView({this.showBack = true, this.onBack, super.key});

  final bool showBack;
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
                const Expanded(child: DetailsHeroBodySkeleton()),
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
