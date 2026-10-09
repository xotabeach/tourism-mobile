import 'package:flutter/material.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

class ExecutionColors {
  static const muted = Color(0xFF8E8E93);
  static const track = Color(0xFFD6E4F7);
  static const ring = Color(0xFFD9D9D9);

  /// DESIGN-4 «не доставлена» red (#FF383C, same as the cross icon).
  static const error = Color(0xFFFF383C);
}

/// Back on the left, the title in the middle and the pause (or resume)
/// control on the right, as in the design.
class ExecutionTopBar extends StatelessWidget {
  const ExecutionTopBar({
    super.key,
    required this.onBack,
    required this.onPause,
    required this.onResume,
  });

  final VoidCallback onBack;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final onPause = this.onPause;
    final onResume = this.onResume;
    return SizedBox(
      height: SettingsMetrics.headerButton,
      child: Row(
        children: [
          Semantics(
            label: 'Назад',
            button: true,
            excludeSemantics: true,
            child: SettingsCircleIconButton(
              icon: Icons.arrow_back_rounded,
              iconSize: 22,
              onTap: onBack,
            ),
          ),
          Expanded(
            child: Text(
              'Прохождение',
              textAlign: TextAlign.center,
              style: AppTypography.settingsRowTitle.copyWith(fontSize: 16),
            ),
          ),
          if (onPause != null)
            Semantics(
              label: 'Пауза',
              button: true,
              excludeSemantics: true,
              child: SettingsCircleIconButton(
                icon: Icons.pause_rounded,
                iconSize: 30,
                onTap: onPause,
              ),
            )
          else if (onResume != null)
            Semantics(
              label: 'Возобновить',
              button: true,
              excludeSemantics: true,
              child: SettingsCircleIconButton(
                icon: Icons.play_arrow_rounded,
                iconSize: 30,
                onTap: onResume,
              ),
            )
          else
            const SizedBox(width: SettingsMetrics.headerButton),
        ],
      ),
    );
  }
}

class ExecutionDarkButton extends StatelessWidget {
  const ExecutionDarkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.primaryInk,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Execution-start failure with the real reason, plus a way out when the
/// blocker is another route already in progress — otherwise this screen is a
/// dead end for anyone who forgot to finish a walk.
class ExecutionErrorView extends StatelessWidget {
  const ExecutionErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onOpenBlocking,
    this.blocking,
  });

  final String message;
  final RouteExecution? blocking;
  final VoidCallback onRetry;
  final VoidCallback onOpenBlocking;

  @override
  Widget build(BuildContext context) {
    final blockingRoute = blocking;
    return Semantics(
      liveRegion: true,
      label: message,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_walk_rounded, size: 32),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (blockingRoute != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Сейчас проходится «${blockingRoute.routeName}»',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryInk,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (blockingRoute != null)
                FilledButton.icon(
                  onPressed: onOpenBlocking,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Открыть активный маршрут'),
                ),
              if (blockingRoute != null) const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
