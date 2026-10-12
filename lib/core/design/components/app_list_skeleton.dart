import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';

/// Rows of placeholder content for a list that is still loading.
///
/// A spinner says "something is happening"; a skeleton says what is about to
/// appear and reserves its space, so the list does not jump when the data
/// lands. Screens that already have a bespoke skeleton keep it — this is for
/// the plain row-shaped lists that were still showing a spinner.
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({
    this.rows = 4,
    this.rowHeight = 64,
    this.showLeading = true,
    this.roundLeading = false,
    this.tiles = false,
    this.gap = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    super.key,
  });

  final int rows;
  final double rowHeight;

  /// Leading square — an avatar or a thumbnail, depending on the list.
  final bool showLeading;

  /// The leading mark is a circle (an avatar) rather than a rounded square.
  final bool roundLeading;

  /// Each row is a white card with a shadow, for lists whose rows are cards
  /// (notifications, achievements, comments) — FRONTEND-71.
  final bool tiles;
  final double gap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final leadingSide = tiles ? rowHeight * 0.6 : rowHeight * 0.72;
    return AppShimmer(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows; i++) ...[
              if (i > 0) SizedBox(height: gap),
              _row(leadingSide),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(double leadingSide) {
    final content = Row(
      children: [
        if (showLeading) ...[
          AppSkeleton(
            width: leadingSide,
            height: leadingSide,
            borderRadius: AppRadii.tile,
            shape: roundLeading ? BoxShape.circle : BoxShape.rectangle,
          ),
          const SizedBox(width: 12),
        ],
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppSkeleton(width: double.infinity, height: 14, borderRadius: 7),
              SizedBox(height: 8),
              // Second line is shorter, like a real subtitle.
              FractionallySizedBox(
                widthFactor: 0.6,
                alignment: Alignment.centerLeft,
                child: AppSkeleton(
                  width: double.infinity,
                  height: 11,
                  borderRadius: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (!tiles) {
      return SizedBox(height: rowHeight, child: content);
    }
    return Container(
      height: rowHeight,
      padding: const EdgeInsets.fromLTRB(14, 0, 40, 0),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.tile,
      ),
      child: content,
    );
  }
}
