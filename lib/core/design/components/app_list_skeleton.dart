import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_radii.dart';
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
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    super.key,
  });

  final int rows;
  final double rowHeight;

  /// Leading square — an avatar or a thumbnail, depending on the list.
  final bool showLeading;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final leadingSide = rowHeight * 0.72;
    return AppShimmer(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              SizedBox(
                height: rowHeight,
                child: Row(
                  children: [
                    if (showLeading) ...[
                      AppSkeleton(
                        width: leadingSide,
                        height: leadingSide,
                        borderRadius: AppRadii.tile,
                      ),
                      const SizedBox(width: 12),
                    ],
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppSkeleton(
                            width: double.infinity,
                            height: 14,
                            borderRadius: 7,
                          ),
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
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
