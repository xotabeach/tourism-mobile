import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

/// Compact root-screen app bar used by the Home chrome.
///
/// [topInset] is explicit so callers that already consume the system safe area
/// can pass zero without creating a second status-bar gap.
class AppBrandBar extends StatelessWidget {
  const AppBrandBar({required this.topInset, this.onBack, super.key});

  final double topInset;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Material(
        color: AppColors.pageSurface,
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.mistDark.withValues(alpha: 0.55),
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page,
              topInset + 2,
              AppSpacing.page,
              6,
            ),
            child: SizedBox(
              height: onBack == null ? 28 : 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      'КРЫМТРИП',
                      style: AppTypography.settingsBrand.copyWith(
                        color: AppColors.settingsBrand,
                        fontSize: 15,
                        height: 1,
                      ),
                    ),
                  ),
                  if (onBack != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        button: true,
                        label: 'Назад',
                        child: SizedBox.square(
                          dimension: 44,
                          child: Material(
                            color: AppColors.activeNavigationFill,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: onBack,
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// App bar that enters from above as page content scrolls away.
class AppScrollBrandBar extends StatelessWidget {
  const AppScrollBrandBar({
    required this.topInset,
    required this.progress,
    required this.onBack,
    super.key,
  });

  final double topInset;
  final double progress;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    return IgnorePointer(
      ignoring: t < 0.98,
      child: ExcludeSemantics(
        excluding: t < 0.98,
        child: Opacity(
          key: const ValueKey('scroll-brand-bar-opacity'),
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, -18 * (1 - t)),
            child: AppBrandBar(topInset: topInset, onBack: onBack),
          ),
        ),
      ),
    );
  }
}
