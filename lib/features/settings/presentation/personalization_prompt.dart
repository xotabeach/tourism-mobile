import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/settings/application/preferences_providers.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Presents the personalization invitation once per authenticated session.
///
/// The invitation is deliberately not shown in the local mock contour: local
/// previews and existing golden tests should remain deterministic, while a
/// real API session gets a useful cold-start nudge after the profile loads.
class PersonalizationPromptHost extends ConsumerStatefulWidget {
  const PersonalizationPromptHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PersonalizationPromptHost> createState() =>
      _PersonalizationPromptHostState();
}

class _PersonalizationPromptHostState
    extends ConsumerState<PersonalizationPromptHost> {
  String? _handledSessionKey;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(
      sessionProvider.select(
        (value) => (
          authenticated: value.isAuthenticated,
          userId: value.userId,
          accessToken: value.accessToken,
        ),
      ),
    );

    if (!session.authenticated || config.useMockData) {
      // A subsequent login must be eligible for its own invitation, even if
      // the previous session was dismissed.
      _handledSessionKey = null;
      return widget.child;
    }

    final preferences = ref.watch(travelPreferencesProvider);
    preferences.whenOrNull(
      data: (value) {
        if (value.isCompleted) {
          return;
        }
        final key = session.userId ?? session.accessToken ?? 'authenticated';
        if (_handledSessionKey == key) {
          return;
        }
        // Mark before scheduling so a provider refresh cannot enqueue several
        // bottom sheets in the same frame.
        _handledSessionKey = key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          unawaited(_showPrompt());
        });
      },
    );

    return widget.child;
  }

  Future<void> _showPrompt() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PersonalizationPromptSheet(
        onLater: () => Navigator.of(sheetContext).pop(),
        onOpen: () {
          Navigator.of(sheetContext).pop();
          // Let the sheet close before pushing a Cupertino settings page.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(
                context.pushNamed(AppRouteNames.settingsChangePreferences),
              );
            }
          });
        },
      ),
    );
  }
}

class _PersonalizationPromptSheet extends StatelessWidget {
  const _PersonalizationPromptSheet({
    required this.onLater,
    required this.onOpen,
  });

  final VoidCallback onLater;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    // Floats as a detached rounded card above the app's own floating nav bar
    // (AppSpacing.shellBottomContent already clears it elsewhere in the
    // shell), rather than sitting edge-to-edge with only the top corners
    // rounded like a stock bottom sheet.
    final bottomMargin =
        MediaQuery.paddingOf(context).bottom + AppSpacing.shellBottomContent;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.floatingNavInset,
        0,
        AppSpacing.floatingNavInset,
        bottomMargin,
      ),
      child: Material(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        elevation: 12,
        shadowColor: const Color(0x33000000),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.lg,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.accentBlue,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Соберём маршруты под вас',
                          style: AppTypography.sectionTitle,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Пара ответов поможет учитывать ваш темп и интересы, '
                          'но мы всё равно оставим место для новых идей.',
                          style: AppTypography.greetingSubtitle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _PromptBenefit(
                icon: Icons.interests_rounded,
                text: 'интересы и любимые места',
              ),
              const SizedBox(height: 9),
              const _PromptBenefit(
                icon: Icons.speed_rounded,
                text: 'комфортная сложность маршрута',
              ),
              const SizedBox(height: 9),
              const _PromptBenefit(
                icon: Icons.family_restroom_rounded,
                text: 'подходящие варианты для семьи и питомца',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Настроить предпочтения'),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onLater,
                  child: const Text('Позже'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptBenefit extends StatelessWidget {
  const _PromptBenefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.accentBlueIcon),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppTypography.greetingSubtitle)),
      ],
    );
  }
}
