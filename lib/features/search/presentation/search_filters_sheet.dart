import 'package:flutter/material.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

enum SearchTarget { profiles, routes, places }

enum SearchSort { byDefault, rating, popular, newest, oldest }

class SearchFilters {
  const SearchFilters({
    this.target,
    this.sort = SearchSort.byDefault,
    this.tags = const <String>{},
  });

  final SearchTarget? target;
  final SearchSort sort;
  final Set<String> tags;

  bool get isActive =>
      target != null || sort != SearchSort.byDefault || tags.isNotEmpty;

  SearchFilters copyWith({
    SearchTarget? target,
    bool clearTarget = false,
    SearchSort? sort,
    Set<String>? tags,
  }) {
    return SearchFilters(
      target: clearTarget ? null : (target ?? this.target),
      sort: sort ?? this.sort,
      tags: tags ?? this.tags,
    );
  }
}

const searchFilterTags = <String>[
  'Море',
  'Горы',
  'Лес',
  'Романтика',
  'Еда',
  'С детьми',
  'Сложные',
  'Отдых',
];

Future<SearchFilters?> showSearchFiltersSheet(
  BuildContext context, {
  SearchFilters initial = const SearchFilters(),
}) {
  return showModalBottomSheet<SearchFilters>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: true,
    useSafeArea: false,
    backgroundColor: AppColors.pageSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height * 0.82;
      return SizedBox(
        key: const ValueKey('search-filters-sheet-content'),
        height: height,
        width: double.infinity,
        child: _SearchFiltersSheet(initial: initial),
      );
    },
  );
}

class _SearchFiltersSheet extends StatefulWidget {
  const _SearchFiltersSheet({required this.initial});

  final SearchFilters initial;

  @override
  State<_SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<_SearchFiltersSheet> {
  late SearchFilters _filters = widget.initial;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            children: [
              const Text('Что ищем?', style: AppTypography.sectionTitle),
              const SizedBox(height: 12),
              for (final target in SearchTarget.values) ...[
                _FilterOptionRow(
                  label: switch (target) {
                    SearchTarget.profiles => 'Пользователи',
                    SearchTarget.routes => 'Маршруты',
                    SearchTarget.places => 'Места',
                  },
                  icon: switch (target) {
                    SearchTarget.profiles => Icons.person_outline_rounded,
                    SearchTarget.routes => Icons.near_me_outlined,
                    SearchTarget.places => Icons.place_outlined,
                  },
                  selected: _filters.target == target,
                  onTap: () => setState(() {
                    _filters = _filters.target == target
                        ? _filters.copyWith(clearTarget: true)
                        : _filters.copyWith(target: target);
                  }),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              const Text('Сортировать', style: AppTypography.sectionTitle),
              const SizedBox(height: 12),
              for (final sort in SearchSort.values) ...[
                _FilterOptionRow(
                  label: switch (sort) {
                    SearchSort.byDefault => 'По умолчанию',
                    SearchSort.rating => 'С высоким рейтингом',
                    SearchSort.popular => 'Сначала популярные',
                    SearchSort.newest => 'Сначала новые',
                    SearchSort.oldest => 'Сначала старые',
                  },
                  selected: _filters.sort == sort,
                  filled: true,
                  onTap: () => setState(() {
                    _filters =
                        _filters.sort == sort && sort != SearchSort.byDefault
                        ? _filters.copyWith(sort: SearchSort.byDefault)
                        : _filters.copyWith(sort: sort);
                  }),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              const Text('Фильтры', style: AppTypography.sectionTitle),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in searchFilterTags)
                    FilterChip(
                      showCheckmark: false,
                      label: Text(tag),
                      selected: _filters.tags.contains(tag),
                      labelStyle: AppTypography.chip.copyWith(
                        color: _filters.tags.contains(tag)
                            ? Colors.white
                            : AppColors.primaryInk,
                        fontWeight: FontWeight.w500,
                      ),
                      backgroundColor: AppColors.controlSurface,
                      selectedColor: AppColors.accentBlue,
                      side: BorderSide(
                        color: _filters.tags.contains(tag)
                            ? AppColors.accentBlue
                            : AppColors.hairline,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      onSelected: (selected) {
                        final tags = {..._filters.tags};
                        if (selected) {
                          tags.add(tag);
                        } else {
                          tags.remove(tag);
                        }
                        setState(
                          () => _filters = _filters.copyWith(tags: tags),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          // Плавающая панель приложения висит поверх шторки, и нижняя кнопка
          // уходила под неё — нажать было нельзя. Отступ снизу учитывает и
          // системную полосу жестов, и высоту этой панели.
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + bottom + AppSpacing.shellBottomContent,
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryInk,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(_filters),
                  child: const Text('Применить'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(const SearchFilters()),
                  child: const Text('Сбросить фильтры'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterOptionRow extends StatelessWidget {
  const _FilterOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.controlSurface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: filled ? null : Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.accentBlue, size: 22),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.settingsRowTitle.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.accentBlue : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.accentBlue : AppColors.hairline,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
