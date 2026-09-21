import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/settings/application/preferences_providers.dart';
import 'package:tourism_mobile/features/settings/data/preferences_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

/// Single choice of the «Предпочитаемая сложность» card. «На транспорте» is a
/// way to travel, stored apart from the difficulty, but chosen here instead
/// of one (design, FRONTEND-21).
const _paceOptions = [
  (_PaceChoice.transport, 'На транспорте'),
  (_PaceChoice.easy, 'Лёгкий'),
  (_PaceChoice.moderate, 'Средний'),
  (_PaceChoice.hard, 'Сложный'),
];

enum _PaceChoice { transport, easy, moderate, hard }

/// "Сменить предпочтения" — a short quiz (interest categories, difficulty,
/// travel companions) that used to be a pure stub with nowhere for an
/// answer to go. Answers reuse the same taxonomy the route catalog already
/// filters on (`preferenceCategories`, `difficulty`), so a completed quiz
/// is immediately useful, not just stored.
class SettingsPreferencesQuizScreen extends ConsumerWidget {
  const SettingsPreferencesQuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(travelPreferencesProvider);
    return prefsAsync.when(
      loading: () => const SettingsScaffold(
        barTitle: 'Настройка предпочтений',
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ),
      error: (_, _) => SettingsScaffold(
        barTitle: 'Настройка предпочтений',
        children: [
          const SizedBox(height: 24),
          const Center(child: Text('Не удалось загрузить предпочтения')),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => ref.invalidate(travelPreferencesProvider),
              child: const Text('Повторить'),
            ),
          ),
        ],
      ),
      data: (prefs) => _QuizBody(initial: prefs),
    );
  }
}

class _QuizBody extends ConsumerStatefulWidget {
  const _QuizBody({required this.initial});

  final TravelPreferences initial;

  @override
  ConsumerState<_QuizBody> createState() => _QuizBodyState();
}

class _QuizBodyState extends ConsumerState<_QuizBody> {
  // Older words (Море, Горы…) are folded by the backend; anything the quiz no
  // longer offers is simply not preselected.
  late final Set<String> _categories = {
    for (final c in widget.initial.categories)
      if (preferenceCategories.contains(c)) c,
  };
  late _PaceChoice? _pace = widget.initial.transport == preferenceTransportCar
      ? _PaceChoice.transport
      : switch (widget.initial.difficulty) {
          'easy' => _PaceChoice.easy,
          'moderate' => _PaceChoice.moderate,
          'hard' => _PaceChoice.hard,
          _ => null,
        };
  late String? _duration = widget.initial.duration;
  late bool _kids = widget.initial.travelsWithKids;
  late bool _pets = widget.initial.travelsWithPets;
  var _busy = false;

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .updatePreferences(
            categories: [
              for (final c in preferenceCategories)
                if (_categories.contains(c)) c,
            ],
            difficulty: switch (_pace) {
              _PaceChoice.easy => 'easy',
              _PaceChoice.moderate => 'moderate',
              _PaceChoice.hard => 'hard',
              _ => null,
            },
            transport: _pace == _PaceChoice.transport
                ? preferenceTransportCar
                : null,
            duration: _duration,
            travelsWithKids: _kids,
            travelsWithPets: _pets,
          );
      ref.invalidate(travelPreferencesProvider);
      if (!mounted) {
        return;
      }
      showAppNotice(context, 'Предпочтения сохранены');
      unawaited(Navigator.of(context).maybePop());
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      showAppNotice(context, error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _reset() {
    setState(() {
      _categories.clear();
      _pace = null;
      _duration = null;
      _kids = false;
      _pets = false;
    });
  }

  bool get _hasSelections =>
      _categories.isNotEmpty ||
      _pace != null ||
      _duration != null ||
      _kids ||
      _pets;

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      barTitle: 'Настройка предпочтений',
      showSave: true,
      onSave: _busy ? null : _submit,
      children: [
        const _PreferencesIntroCard(),
        _ChoiceCard(
          iconAsset: AppIconography.settingsPrefInterests,
          title: 'Ваши интересы:',
          subtitle: 'Выберите хотя бы один интерес',
          options: [
            for (final category in preferenceCategories)
              _ChoiceOption(
                label: category,
                selected: _categories.contains(category),
                onTap: () => setState(() {
                  if (!_categories.remove(category)) {
                    _categories.add(category);
                  }
                }),
              ),
          ],
        ),
        _ChoiceCard(
          iconAsset: AppIconography.settingsPrefDifficulty,
          title: 'Предпочитаемая сложность:',
          subtitle: 'Подстроим темп и длину под вас',
          options: [
            for (final (value, label) in _paceOptions)
              _ChoiceOption(
                label: label,
                selected: _pace == value,
                onTap: () =>
                    setState(() => _pace = _pace == value ? null : value),
              ),
          ],
        ),
        _ChoiceCard(
          iconAsset: AppIconography.settingsPrefDuration,
          title: 'Длительность маршрута:',
          subtitle: 'На сколько вы обычно уезжаете отдыхать',
          options: [
            for (final (value, label) in preferenceDurations)
              _ChoiceOption(
                label: label,
                selected: _duration == value,
                onTap: () => setState(
                  () => _duration = _duration == value ? null : value,
                ),
              ),
          ],
        ),
        SettingsToggleTile(
          title: 'Путешествие с детьми',
          subtitle: 'Больше спокойных и безопасных мест',
          iconAsset: AppIconography.settingsPrefKids,
          value: _kids,
          onChanged: (value) => setState(() => _kids = value),
        ),
        SettingsToggleTile(
          title: 'Путешествие с питомцем',
          subtitle: 'Больше равнин и природы',
          iconAsset: AppIconography.settingsPrefPets,
          value: _pets,
          onChanged: (value) => setState(() => _pets = value),
        ),
        if (_hasSelections)
          Center(
            child: TextButton.icon(
              onPressed: _busy ? null : _reset,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Сбросить все ответы'),
            ),
          ),
      ],
    );
  }
}

class _PreferencesIntroCard extends StatelessWidget {
  const _PreferencesIntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.settingsTile),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF4FA3E3), Color(0xFF3B74D9)],
        ),
        border: Border.all(color: const Color(0xFF3B74D9), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Image.asset(
              AppIconography.promptStar,
              width: 24,
              height: 24,
              color: Colors.white,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Всего несколько ответов',
                  style: AppTypography.settingsRowTitle.copyWith(
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'И ваши рекомендации станут более точнее, а лента не станет '
                  'однообразным фильтром.',
                  style: AppTypography.settingsRowSubtitle.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceOption {
  const _ChoiceOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
}

/// A quiz question: icon, title and hint, a hairline, then a two-column grid
/// of equal buttons (design).
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.options,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
  final List<_ChoiceOption> options;

  @override
  Widget build(BuildContext context) {
    return SettingsFormCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAssetIcon(
                iconAsset,
                size: AppIconography.settings,
                color: SettingsColors.accentIcon,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.settingsRowTitle),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.settingsRowSubtitle.copyWith(
                        color: AppColors.settingsSecondaryInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const SettingsHairline(),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - AppSpacing.xs) / 2;
              return Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final option in options)
                    SizedBox(
                      width: width,
                      child: _QuizChip(
                        label: option.label,
                        selected: option.selected,
                        onTap: option.onTap,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuizChip extends StatelessWidget {
  const _QuizChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label${selected ? ', выбрано' : ''}',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.accentBlue : AppColors.elevatedSurface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            height: 32,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: selected
                  ? null
                  : Border.all(color: const Color(0xFFD9D9DB)),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.settingsRowSubtitle.copyWith(
                fontSize: 13,
                color: selected ? Colors.white : AppColors.primaryInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
