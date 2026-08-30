import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/settings/application/preferences_providers.dart';
import 'package:tourism_mobile/features/settings/data/preferences_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

const _difficultyOptions = [
  ('easy', 'Лёгкий'),
  ('moderate', 'Средний'),
  ('hard', 'Сложный'),
];

const _categoryIcons = <String, IconData>{
  'Море': Icons.waves_rounded,
  'Горы': Icons.terrain_rounded,
  'Еда': Icons.restaurant_rounded,
  'Лес': Icons.forest_rounded,
};

const _difficultyIcons = <String, IconData>{
  'easy': Icons.directions_walk_rounded,
  'moderate': Icons.hiking_rounded,
  'hard': Icons.trending_up_rounded,
};

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
        title: 'Предпочтения:',
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
        title: 'Предпочтения:',
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
  late final Set<String> _categories = {...widget.initial.categories};
  late String? _difficulty = widget.initial.difficulty;
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
            categories: _categories.toList(),
            difficulty: _difficulty,
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
      _difficulty = null;
      _kids = false;
      _pets = false;
    });
  }

  bool get _hasSelections =>
      _categories.isNotEmpty || _difficulty != null || _kids || _pets;

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Предпочтения:',
      subtitle: 'Поможет точнее подбирать маршруты и места',
      showSave: true,
      onSave: _busy ? null : _submit,
      children: [
        const _PreferencesIntroCard(),
        SettingsFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Что вам интересно:',
                          style: AppTypography.settingsRowTitle.copyWith(
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _categories.isEmpty
                              ? 'Выберите хотя бы один интерес'
                              : '${_categories.length} ${_interestWord(_categories.length)} выбрано',
                          style: AppTypography.settingsRowSubtitle.copyWith(
                            fontSize: 11,
                            color: _categories.isEmpty
                                ? AppColors.settingsSecondaryInk
                                : AppColors.accentBlueIcon,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_categories.isNotEmpty)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(_categories.clear),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Очистить'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in preferenceCategories)
                    _QuizChip(
                      label: category,
                      icon: _categoryIcons[category],
                      selected: _categories.contains(category),
                      onTap: () => setState(() {
                        if (!_categories.remove(category)) {
                          _categories.add(category);
                        }
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Предпочитаемая сложность:',
                style: AppTypography.settingsRowTitle.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'Подстроим темп и длину подсказок под вас',
                style: AppTypography.settingsRowSubtitle.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label) in _difficultyOptions)
                    _QuizChip(
                      label: label,
                      icon: _difficultyIcons[value],
                      selected: _difficulty == value,
                      onTap: () => setState(
                        () => _difficulty = _difficulty == value ? null : value,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsToggleTile(
          title: 'Путешествую с детьми',
          subtitle: 'Будем чаще предлагать маршруты, подходящие для детей',
          icon: Icons.child_care_rounded,
          value: _kids,
          onChanged: (value) => setState(() => _kids = value),
        ),
        const SizedBox(height: 12),
        SettingsToggleTile(
          title: 'Путешествую с питомцем',
          subtitle: 'Будем чаще предлагать маршруты, где разрешены животные',
          icon: Icons.pets_rounded,
          value: _pets,
          onChanged: (value) => setState(() => _pets = value),
        ),
        if (_hasSelections) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: _busy ? null : _reset,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Сбросить все ответы'),
            ),
          ),
        ],
      ],
    );
  }

  static String _interestWord(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'интересов';
    if (mod10 == 1) return 'интерес';
    if (mod10 >= 2 && mod10 <= 4) return 'интереса';
    return 'интересов';
  }
}

class _PreferencesIntroCard extends StatelessWidget {
  const _PreferencesIntroCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentBlue.withValues(alpha: 0.14),
            AppColors.accentBlue.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.settingsTile),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(11),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.accentBlue,
                  size: 23,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Ответьте на несколько вопросов — рекомендации станут точнее, '
                'а лента не превратится в однообразный фильтр.',
                style: AppTypography.settingsRowSubtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizChip extends StatelessWidget {
  const _QuizChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label${selected ? ', выбрано' : ''}',
      child: Material(
        color: selected ? AppColors.accentBlue : AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.capsule),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.capsule),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.capsule),
              border: selected ? null : Border.all(color: AppColors.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 17,
                    color: selected ? Colors.white : AppColors.accentBlueIcon,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: AppTypography.settingsRowTitle.copyWith(
                    fontSize: 14,
                    color: selected ? Colors.white : AppColors.primaryInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
