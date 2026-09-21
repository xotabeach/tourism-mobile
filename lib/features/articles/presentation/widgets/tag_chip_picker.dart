import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

/// A wrapping row of toggle chips for picking up to [maxSelected] tags.
///
/// `AppFilterChipBar`/`AppSegmentedToggle` are both single-select and force
/// equal-width `Expanded` children — the wrong shape for a tag row that
/// wraps and has arbitrary-width labels, so this is its own small widget.
/// Pass `onToggle: null` for a read-only display row (the reading screen's
/// tag list) — chips render with no ink response and can't be tapped.
class TagChipPicker extends StatefulWidget {
  const TagChipPicker({
    required this.tags,
    required this.selected,
    this.onToggle,
    this.maxSelected,
    this.collapsedCount,
    super.key,
  }) : displayOnly = false;

  /// Read-only row of an article's own tags (the reading screen). Тёмно-серая
  /// «таблетка» со светлым текстом — со скрина «Страница блога» (замер
  /// заливки #5E5E5E). Светлый чип, который был здесь раньше, спорил с
  /// чипами-фильтрами: те выбираются, эти — просто подпись.
  const TagChipPicker.display({required this.tags, super.key})
    : selected = const {},
      onToggle = null,
      maxSelected = null,
      collapsedCount = null,
      displayOnly = true;

  final List<String> tags;
  final Set<String> selected;
  final ValueChanged<String>? onToggle;
  final int? maxSelected;

  /// Сколько чипов показывать в свёрнутом виде. Остальные прячутся за
  /// «Показать все» — шестнадцать тегов подряд занимали пол-экрана и
  /// отодвигали содержание статьи далеко вниз.
  final int? collapsedCount;
  final bool displayOnly;

  @override
  State<TagChipPicker> createState() => _TagChipPickerState();
}

class _TagChipPickerState extends State<TagChipPicker> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final atLimit =
        widget.maxSelected != null &&
        widget.selected.length >= widget.maxSelected!;
    final limit = widget.collapsedCount;
    // Выбранные показываем всегда: иначе отметка исчезала бы под «Показать
    // все» и выглядела как потерянная.
    final visible = limit == null || _expanded
        ? widget.tags
        : [
                ...widget.tags.where(widget.selected.contains),
                ...widget.tags.where((tag) => !widget.selected.contains(tag)),
              ]
              .take(
                limit < widget.selected.length ? widget.selected.length : limit,
              )
              .toList();
    final hidden = widget.tags.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          // The editor's tighter rhythm; the reading screen keeps its own.
          spacing: widget.displayOnly ? 8 : 5,
          runSpacing: widget.displayOnly ? 8 : 6,
          children: [
            for (final tag in visible)
              _TagChip(
                label: tag,
                selected: widget.selected.contains(tag),
                displayOnly: widget.displayOnly,
                onTap: widget.onToggle == null
                    ? null
                    : (atLimit && !widget.selected.contains(tag))
                    ? null
                    : () => widget.onToggle!(tag),
              ),
          ],
        ),
        if (limit != null && (hidden > 0 || _expanded)) ...[
          const SizedBox(height: 8),
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              key: const ValueKey('tag-picker-toggle'),
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(AppRadii.capsule),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  _expanded ? 'Свернуть' : 'Показать все',
                  style: AppTypography.chip.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.accentBlue,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.displayOnly,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool displayOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      // The editor's chips as drawn: 25.6 tall, a pale fill and a grey edge.
      padding: EdgeInsets.symmetric(
        horizontal: displayOnly ? 14 : 11,
        vertical: displayOnly ? 7 : 5,
      ),
      decoration: BoxDecoration(
        color: displayOnly
            ? const Color(0xFF5E5E5E)
            : selected
            ? AppColors.primaryInk
            : const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: displayOnly
            ? null
            : Border.all(
                color: selected
                    ? AppColors.primaryInk
                    : const Color(0xFFDCDCDC),
              ),
      ),
      child: Text(
        label,
        style: AppTypography.chip.copyWith(
          fontSize: 13,
          height: displayOnly ? null : 1.2,
          color: displayOnly || selected ? Colors.white : AppColors.primaryInk,
          fontWeight: displayOnly ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
    );
    if (onTap == null) {
      return chip;
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.chip),
        onTap: onTap,
        child: chip,
      ),
    );
  }
}
