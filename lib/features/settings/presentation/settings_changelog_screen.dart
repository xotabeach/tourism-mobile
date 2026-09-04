import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/settings/domain/changelog.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

/// История изменений по версиям.
///
/// Читают её не разработчики, поэтому версия — это заголовок, а под ним
/// понятные строки, сгруппированные по смыслу: что появилось, что стало
/// работать иначе, что починили.
class SettingsChangelogScreen extends StatelessWidget {
  const SettingsChangelogScreen({super.key});

  static const routePath = 'changelog';

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'История изменений:',
      spaceChildren: false,
      children: [
        for (final release in appChangelog) ...[
          _ReleaseCard(release: release),
          const SizedBox(height: SettingsMetrics.rowGap),
        ],
      ],
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release});

  final AppRelease release;

  @override
  Widget build(BuildContext context) {
    return SettingsFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Версия ${release.version}',
                style: AppTypography.settingsRowTitle.copyWith(fontSize: 16),
              ),
              const SizedBox(width: 8),
              if (release.inProgress)
                const _Badge(text: 'Готовится', color: AppColors.accentBlue)
              else if (release.date != null)
                // Дата длиннее номера версии («3 сентября 2026») и на узком
                // экране распирала строку — поэтому ужимается она, а не ряд.
                Flexible(
                  child: Text(
                    release.date!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.settingsRowSubtitle,
                  ),
                ),
            ],
          ),
          for (final kind in ChangeKind.values)
            if (release.entriesOf(kind).isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                kind.label,
                style: AppTypography.chip.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryInk,
                ),
              ),
              const SizedBox(height: 6),
              for (final entry in release.entriesOf(kind))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 8),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.secondaryInk,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.text,
                          style: AppTypography.settingsRowSubtitle.copyWith(
                            height: 1.35,
                            color: AppColors.primaryInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.capsule),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          text,
          style: AppTypography.chip.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
