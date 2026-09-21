import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
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
      builder: (sheetContext) => PersonalizationPromptCard(
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

@visibleForTesting
class PersonalizationPromptCard extends StatelessWidget {
  const PersonalizationPromptCard({
    super.key,
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
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        elevation: 12,
        shadowColor: const Color(0x33000000),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _promptBlue.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: _promptBlue, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Image.asset(
                      AppIconography.promptStar,
                      width: 28,
                      height: 28,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Соберём маршруты\nпод ваши предпочтения',
                          style: AppTypography.sectionTitle.copyWith(
                            fontSize: 18,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFE6E6E8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Пара ответов поможет учитывать ваш темп и интересы, но мы '
                'всё равно оставим место для новых идей.',
                style: AppTypography.greetingSubtitle.copyWith(
                  fontSize: 14,
                  height: 1.35,
                  color: AppColors.secondaryInk,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 1, color: _promptBlue),
              const SizedBox(height: 10),
              const _PromptBenefit(
                iconAsset: AppIconography.promptInterests,
                text: 'Интересы и любимые места',
              ),
              const SizedBox(height: 8),
              const _PromptBenefit(
                iconAsset: AppIconography.promptDifficulty,
                text: 'Комфортная сложность маршрута',
              ),
              const SizedBox(height: 8),
              const _PromptBenefit(
                iconAsset: AppIconography.promptFamily,
                text: 'Варианты для семьи и питомца',
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 1, color: _promptBlue),
              const SizedBox(height: 14),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryInk,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    textStyle: AppTypography.sectionTitle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  child: const Text('Настроить предпочтения'),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: onLater,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryInk,
                    textStyle: AppTypography.sectionTitle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
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

/// The icon blue of the pop-up design.
const _promptBlue = Color(0xFF1E71CA);

class _PromptBenefit extends StatelessWidget {
  const _PromptBenefit({required this.iconAsset, required this.text});

  final String iconAsset;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          iconAsset,
          width: 24,
          height: 24,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTypography.greetingSubtitle.copyWith(
              fontSize: 14,
              color: AppColors.secondaryInk,
            ),
          ),
        ),
        Image.asset(
          AppIconography.promptCheck,
          width: 24,
          height: 24,
          excludeFromSemantics: true,
        ),
      ],
    );
  }
}
