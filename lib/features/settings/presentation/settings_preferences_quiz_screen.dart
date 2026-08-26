import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/settings/application/preferences_providers.dart';
import 'package:tourism_mobile/features/settings/data/preferences_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

const _difficultyOptions = [
  ('easy', 'Лёгкий'),
  ('moderate', 'Средний'),
  ('hard', 'Сложный'),
];

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Предпочтения сохранены')));
      unawaited(Navigator.of(context).maybePop());
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Предпочтения:',
      subtitle: 'Поможет точнее подбирать маршруты и места',
      showSave: true,
      onSave: _busy ? null : _submit,
      children: [
        SettingsFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Что вам интересно:',
                style: AppTypography.settingsRowTitle.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'Можно выбрать несколько вариантов',
                style: AppTypography.settingsRowSubtitle.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in preferenceCategories)
                    _QuizChip(
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label) in _difficultyOptions)
                    _QuizChip(
                      label: label,
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
      ],
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
    return Material(
      color: selected ? AppColors.accentBlue : AppColors.elevatedSurface,
      borderRadius: BorderRadius.circular(AppRadii.capsule),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.capsule),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.capsule),
            border: selected ? null : Border.all(color: AppColors.hairline),
          ),
          child: Text(
            label,
            style: AppTypography.settingsRowTitle.copyWith(
              fontSize: 14,
              color: selected ? Colors.white : AppColors.primaryInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
