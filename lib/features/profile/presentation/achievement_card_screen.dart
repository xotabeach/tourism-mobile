import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';
import 'package:tourism_mobile/features/profile/presentation/widgets/achievement_icons.dart';

/// Full card for a single achievement.
///
/// Replaces the snackbar that used to just echo the badge title: shows what
/// the badge is, how it is earned, and — when the traveller has it — exactly
/// when they got it.
class AchievementCardScreen extends StatelessWidget {
  const AchievementCardScreen({required this.achievement, super.key});

  final ProfileAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final unlockedAt = achievement.unlockedAt;
    final rule = achievement.howToEarn.trim();
    final description = achievement.description.trim();
    // The seeded catalogue stores the rule in `description`, so showing both
    // would repeat the same sentence twice.
    final showDescription = description.isNotEmpty && description != rule;

    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      appBar: AppBar(
        backgroundColor: AppColors.pageSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Достижение'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _AchievementBadge(
                  unlocked: achievement.isUnlocked,
                  iconSlug: achievement.iconSlug,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                style: AppTypography.routeTitle.copyWith(
                  fontSize: 22,
                  color: AppColors.primaryInk,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: _StatusChip(
                  unlocked: achievement.isUnlocked,
                  unlockedAt: unlockedAt,
                ),
              ),
              if (showDescription) ...[
                const SizedBox(height: 22),
                _Section(title: 'Описание', body: description),
              ],
              if (rule.isNotEmpty) ...[
                const SizedBox(height: 18),
                _Section(title: 'Как получить', body: rule),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({required this.unlocked, required this.iconSlug});

  final bool unlocked;
  final String iconSlug;

  @override
  Widget build(BuildContext context) {
    final icon = achievementIconFor(iconSlug);
    return Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        color: unlocked ? AppColors.primaryInk : AppColors.controlSurface,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 54,
        color: unlocked ? Colors.white : AppColors.secondaryInk,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.unlocked, required this.unlockedAt});

  final bool unlocked;
  final DateTime? unlockedAt;

  static String _stamp(DateTime value) {
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year}'
        ' в ${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final earned = unlockedAt;
    final label = !unlocked
        ? 'Ещё не получено'
        : earned == null
        ? 'Получено'
        : 'Получено ${_stamp(earned)}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: unlocked
            ? AppColors.primaryInk.withValues(alpha: 0.08)
            : AppColors.controlSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Text(
          label,
          style: AppTypography.settingsRowSubtitle.copyWith(
            fontSize: 13,
            color: unlocked ? AppColors.primaryInk : AppColors.secondaryInk,
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.settingsRowTitle.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: AppTypography.settingsRowSubtitle.copyWith(
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// Opens [AchievementCardScreen] above the current tab.
void openAchievementCard(BuildContext context, ProfileAchievement achievement) {
  unawaited(
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AchievementCardScreen(achievement: achievement),
      ),
    ),
  );
}
