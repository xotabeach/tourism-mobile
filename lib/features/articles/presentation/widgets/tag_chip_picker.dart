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
class TagChipPicker extends StatelessWidget {
  const TagChipPicker({
    required this.tags,
    required this.selected,
    this.onToggle,
    this.maxSelected,
    super.key,
  }) : displayOnly = false;

  /// Read-only row of an article's own tags (the reading screen). Renders the
  /// quieter filled-light chip from the design rather than the editor's
  /// dark selected/outlined unselected pair — nothing here is a control.
  const TagChipPicker.display({required this.tags, super.key})
    : selected = const {},
      onToggle = null,
      maxSelected = null,
      displayOnly = true;

  final List<String> tags;
  final Set<String> selected;
  final ValueChanged<String>? onToggle;
  final int? maxSelected;
  final bool displayOnly;

  @override
  Widget build(BuildContext context) {
    final atLimit = maxSelected != null && selected.length >= maxSelected!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          _TagChip(
            label: tag,
            selected: selected.contains(tag),
            displayOnly: displayOnly,
            onTap: onToggle == null
                ? null
                : (atLimit && !selected.contains(tag))
                ? null
                : () => onToggle!(tag),
          ),
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
      padding: EdgeInsets.symmetric(
        horizontal: displayOnly ? 13 : 15,
        vertical: displayOnly ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: displayOnly
            ? const Color(0xFFF0F0F0)
            : selected
            ? AppColors.primaryInk
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: displayOnly
            ? null
            : Border.all(
                color: selected ? AppColors.primaryInk : const Color(0xFFD9D9DB),
              ),
      ),
      child: Text(
        label,
        style: AppTypography.chip.copyWith(
          fontSize: displayOnly ? 12 : 14,
          color: selected && !displayOnly
              ? Colors.white
              : AppColors.primaryInk,
          fontWeight: FontWeight.w500,
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
