import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/settings/application/app_icon_service.dart';

/// Picking a launcher icon — a Travel+ perk.
///
/// The icons themselves ship with the build (both platforms read them at
/// install time), so a reader without a subscription sees the full set and
/// what it would unlock, rather than an empty screen.
class SettingsAppIconScreen extends ConsumerStatefulWidget {
  const SettingsAppIconScreen({super.key});

  static const routePath = 'app-icon';

  @override
  ConsumerState<SettingsAppIconScreen> createState() =>
      _SettingsAppIconScreenState();
}

class _SettingsAppIconScreenState extends ConsumerState<SettingsAppIconScreen> {
  var _applying = false;

  Future<void> _select(AppIconVariant variant, {required bool unlocked}) async {
    if (_applying) return;
    if (!unlocked && variant != AppIconVariant.standard) {
      showAppNotice(context, 'Другие иконки доступны с подпиской Тревел+');
      return;
    }
    setState(() => _applying = true);
    final error = await ref.read(appIconServiceProvider).apply(variant);
    if (!mounted) return;
    setState(() => _applying = false);
    if (error != null) {
      showAppNotice(context, error);
      return;
    }
    ref.invalidate(currentAppIconProvider);
    showAppNotice(context, 'Иконка «${variant.label}» установлена');
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(sessionProvider).travelPlusActive;
    final current = ref.watch(currentAppIconProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      appBar: AppBar(
        backgroundColor: AppColors.pageSurface,
        elevation: 0,
        title: const Text(
          'Иконка приложения',
          style: AppTypography.sectionTitle,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          if (!unlocked)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.accentBlue.withValues(alpha: 0.24),
                  ),
                ),
                child: const Text(
                  'Сменить иконку можно с подпиской Тревел+.',
                  style: AppTypography.routeMetadata,
                ),
              ),
            ),
          for (final variant in AppIconVariant.values) ...[
            _IconRow(
              variant: variant,
              selected: current == variant,
              locked: !unlocked && variant != AppIconVariant.standard,
              onTap: () => unawaited(_select(variant, unlocked: unlocked)),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Иконка на домашнем экране обновится сразу или через несколько '
            'секунд — это зависит от лаунчера.',
            style: AppTypography.routeMetadata,
          ),
        ],
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({
    required this.variant,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final AppIconVariant variant;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.elevatedSurface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        key: ValueKey('app-icon-${variant.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Opacity(
                opacity: locked ? 0.45 : 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    variant.previewAsset,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  variant.label,
                  style: AppTypography.chip.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: locked
                        ? AppColors.secondaryInk
                        : AppColors.primaryInk,
                  ),
                ),
              ),
              if (locked)
                const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.secondaryInk,
                  size: 20,
                )
              else if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.accentBlue,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
