import 'package:flutter/material.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/execution_chrome.dart';

class ExecutionProgressCard extends StatelessWidget {
  const ExecutionProgressCard({super.key, required this.execution});

  final RouteExecution execution;

  static const _label = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: ExecutionColors.muted,
  );

  @override
  Widget build(BuildContext context) {
    final percent = (execution.progress * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.tile,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Прогресс:', style: _label),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.accentBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: execution.progress,
                backgroundColor: ExecutionColors.track,
                color: AppColors.accentBlue,
              ),
            ),
            const SizedBox(height: 10),
            if (execution.totalStops == 0)
              const Text(
                'Остановки появятся после синхронизации маршрута',
                style: _label,
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Остановки:',
                    style: _label.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    '${execution.completedStops}/${execution.totalStops}',
                    style: const TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: AppColors.primaryInk,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// «Всего в пути: 174 мин.»: a pill with a blue icon, the label on the left
/// and the value on the right.
class ExecutionInfoRow extends StatelessWidget {
  const ExecutionInfoRow({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.value,
  });

  final String iconAsset;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Container(
        height: 43,
        padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFEFEFF1)),
        ),
        child: Row(
          children: [
            AppAssetIcon(iconAsset, size: 24, color: AppColors.accentBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: ExecutionColors.muted,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: AppColors.primaryInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExecutionOfflineBanner extends StatelessWidget {
  const ExecutionOfflineBanner({
    super.key,
    required this.pendingActions,
    required this.onRetry,
  });

  final int pendingActions;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.accentBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                pendingActions == 0
                    ? 'Офлайн-сеанс. Данные сохранены на устройстве.'
                    : 'Офлайн-сеанс. Действий к синхронизации: $pendingActions.',
                style: AppTypography.routeMetadata.copyWith(
                  color: AppColors.primaryInk,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

class ExecutionWarningCard extends StatelessWidget {
  const ExecutionWarningCard({super.key, required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5DF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF9A6500)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Проверь актуальность дороги и погоды перед выходом. ${warnings.take(2).join(', ')}',
                style: AppTypography.routeMetadata.copyWith(
                  color: const Color(0xFF6E4B00),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
