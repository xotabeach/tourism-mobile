import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/route_execution/application/active_leg.dart';

/// «Сейчас в пути · участок 2–3» above the run map (FRONTEND-22): where to
/// go next in large type, where from with the leg's length below.
///
/// A provisional look until the DESIGN-5 mockup: the accent stripe matches
/// the leg line on the map, so the card and the line read as one thing.
class ActiveLegCard extends StatelessWidget {
  const ActiveLegCard({required this.leg, this.onShowOnMap, super.key});

  final ActiveLegInfo leg;

  /// Opens the expanded map framed on this leg.
  final VoidCallback? onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final meta = leg.meta;
    return Semantics(
      container: true,
      label:
          'Сейчас в пути: ${leg.from.placeName}, затем ${leg.to.placeName}'
          '${meta == null ? '' : ', $meta'}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ColoredBox(
                  color: AppColors.accentBlue,
                  child: SizedBox(width: 5),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Сейчас в пути · ${leg.title}',
                            style: AppTypography.routeMetadata.copyWith(
                              color: AppColors.accentBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            leg.to.placeName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.routeMetadata.copyWith(
                              color: AppColors.primaryInk,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'от «${leg.from.placeName}»',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.routeMetadata.copyWith(
                              color: AppColors.secondaryInk,
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                          if (meta != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              meta,
                              maxLines: 1,
                              style: AppTypography.routeMetadata.copyWith(
                                color: AppColors.primaryInk,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (onShowOnMap != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        tooltip: 'Участок на карте',
                        onPressed: onShowOnMap,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.accentBlue.withValues(
                            alpha: 0.1,
                          ),
                        ),
                        icon: const Icon(
                          Icons.zoom_in_map_rounded,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
