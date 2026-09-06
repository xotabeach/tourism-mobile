import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

/// A quiet "you're offline, showing what's saved on this device" strip.
///
/// Same visual language as the route-execution offline banner, but without
/// its retry/outbox affordance — this one is for screens that simply switch
/// to a cached data source rather than queue mutations.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({this.message = 'Офлайн. Показано сохранённое на устройстве.', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.accentBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.accentBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.routeMetadata.copyWith(
                    color: AppColors.primaryInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
