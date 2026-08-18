import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

/// Full-screen achievements catalog (Figma «Достижения»).
///
/// Header «Достижения:» + segment «Полученные/Все» + search field
/// «Искать достижение» + vertical badge feed with unlocked/locked states.
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  static const routePath = 'achievements';

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

enum _AchievementFilter { unlocked, all }

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  final _searchController = TextEditingController();
  var _filter = _AchievementFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(sessionProvider).userId ?? 'mock-user';
    final catalog = ref.watch(userAchievementsProvider(userId));

    return catalog.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => const SettingsScaffold(
        title: 'Достижения:',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (_, _) => SettingsScaffold(
        title: 'Достижения:',
        children: [
          const Text('Не удалось загрузить достижения'),
          TextButton(
            onPressed: () => ref.invalidate(userAchievementsProvider(userId)),
            child: const Text('Повторить'),
          ),
        ],
      ),
      data: _buildCatalog,
    );
  }

  Widget _buildCatalog(List<ProfileAchievement> all) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = [
      for (final achievement in all)
        if (_filter == _AchievementFilter.all || achievement.isUnlocked)
          if (query.isEmpty ||
              achievement.title.toLowerCase().contains(query) ||
              achievement.description.toLowerCase().contains(query))
            achievement,
    ];
    final unlockedCount = all
        .where((achievement) => achievement.isUnlocked)
        .length;

    return SettingsScaffold(
      title: 'Достижения:',
      subtitle: 'Получено $unlockedCount из ${all.length}',
      children: [
        AppFilterChipBar(
          labels: const ['Все', 'Полученные'],
          selected: _filter == _AchievementFilter.all ? 'Все' : 'Полученные',
          onSelected: (label) {
            setState(() {
              _filter = label == 'Все'
                  ? _AchievementFilter.all
                  : _AchievementFilter.unlocked;
            });
          },
        ),
        _AchievementSearchField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          onClear: () => setState(() {}),
        ),
        if (visible.isEmpty)
          _EmptyAchievements(query: query)
        else
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _AchievementBadgeRow(achievement: visible[i]),
          ],
        const SizedBox(height: AppSpacing.shellBottomContent),
      ],
    );
  }
}

/// Search field with the shared 48 px control-surface pill look.
class _AchievementSearchField extends StatefulWidget {
  const _AchievementSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_AchievementSearchField> createState() =>
      _AchievementSearchFieldState();
}

class _AchievementSearchFieldState extends State<_AchievementSearchField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'achievements-search');
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _AchievementSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final showClose = _focusNode.hasFocus || widget.controller.text.isNotEmpty;
    return SizedBox(
      height: 48,
      child: Material(
        color: AppColors.controlSurface,
        borderRadius: BorderRadius.circular(AppRadii.field),
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.search,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.2,
            letterSpacing: 0,
            color: AppColors.primaryInk,
          ),
          decoration: InputDecoration(
            hintText: 'Искать достижение',
            hintStyle: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.2,
              letterSpacing: 0,
              color: AppColors.secondaryInk,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
            prefixIconConstraints: const BoxConstraints.tightFor(
              width: 46,
              height: 48,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Center(
                child: AppAssetIcon(
                  AppIconography.search,
                  size: 24,
                  color: AppColors.secondaryInk,
                ),
              ),
            ),
            suffixIconConstraints: const BoxConstraints.tightFor(
              width: 42,
              height: 48,
            ),
            suffixIcon: showClose
                ? IconButton(
                    tooltip: 'Очистить поиск',
                    onPressed: () {
                      widget.controller.clear();
                      widget.onClear();
                      _focusNode.unfocus();
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _AchievementBadgeRow extends StatelessWidget {
  const _AchievementBadgeRow({required this.achievement});

  final ProfileAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked;
    return Semantics(
      label:
          '${achievement.title}: ${achievement.description}. '
          '${unlocked ? 'Получено' : 'Заблокировано'}',
      child: SizedBox(
        width: double.infinity,
        child: AppPressableScale(
          borderRadius: AppRadii.card,
          onTap: unlocked ? () => _snack(context, achievement.title) : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: unlocked
                  ? AppColors.elevatedSurface
                  : const Color(0x59E7E7E7),
              borderRadius: BorderRadius.circular(AppRadii.card),
              boxShadow: unlocked ? AppShadows.tile : null,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              child: Row(
                children: [
                  _BadgeMedal(unlocked: unlocked),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          achievement.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.chip.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: unlocked
                                ? AppColors.primaryInk
                                : AppColors.secondaryInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          achievement.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.routeMetadata.copyWith(
                            color: AppColors.secondaryInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _BadgeStateIcon(unlocked: unlocked),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeStateIcon extends StatelessWidget {
  const _BadgeStateIcon({required this.unlocked});

  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: unlocked ? const Color(0xFF34C759) : const Color(0xFFFF4D4F),
          width: 1.4,
        ),
      ),
      child: Icon(
        unlocked ? Icons.check_rounded : Icons.close_rounded,
        size: 18,
        color: unlocked ? const Color(0xFF34C759) : const Color(0xFFFF4D4F),
      ),
    );
  }
}

class _BadgeMedal extends StatelessWidget {
  const _BadgeMedal({required this.unlocked});

  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: unlocked ? AppColors.accentBlue : const Color(0xFFCFCFD2),
        shape: BoxShape.circle,
      ),
      child: unlocked
          ? const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 24,
            )
          : const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
    );
  }
}

class _EmptyAchievements extends StatelessWidget {
  const _EmptyAchievements({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 48,
            color: AppColors.secondaryInk,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            query.isEmpty ? 'Пока нет достижений' : 'Ничего не найдено',
            textAlign: TextAlign.center,
            style: AppTypography.sectionTitle,
          ),
          const SizedBox(height: 4),
          Text(
            query.isEmpty
                ? 'Проходите маршруты, чтобы открывать новые бейджи'
                : 'Попробуйте изменить запрос',
            textAlign: TextAlign.center,
            style: AppTypography.routeMetadata.copyWith(
              color: AppColors.secondaryInk,
            ),
          ),
        ],
      ),
    );
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
