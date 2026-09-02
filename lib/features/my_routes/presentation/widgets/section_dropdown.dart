import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';

/// One choice in [SectionDropdown].
class SectionOption<T> {
  const SectionOption({
    required this.value,
    required this.label,
    required this.icon,
    this.count,
  });

  final T value;
  final String label;
  final IconData icon;

  /// Optional badge — how many items that section holds right now.
  final int? count;
}

/// A single collapsed row that expands into the full list of sections.
///
/// Replaces the grid of pill chips this screen used to have: at four
/// sections the grid already took two rows, and a fifth ("Статьи") would
/// have left a lone chip dangling on the second row. A dropdown keeps the
/// chrome to one row no matter how many sections there are.
class SectionDropdown<T> extends StatefulWidget {
  const SectionDropdown({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<SectionOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  State<SectionDropdown<T>> createState() => _SectionDropdownState<T>();
}

class _SectionDropdownState<T> extends State<SectionDropdown<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.emphasized,
    reverseDuration: AppMotion.normal,
  );

  late final Animation<double> _expand = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.emphasizedCurve,
    reverseCurve: AppMotion.standard,
  );

  bool get _isOpen => _controller.status == AnimationStatus.forward ||
      _controller.status == AnimationStatus.completed;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    unawaited(AppHaptics.selectionClick());
    unawaited(_isOpen ? _controller.reverse() : _controller.forward());
    setState(() {});
  }

  void _pick(T value) {
    unawaited(AppHaptics.selectionClick());
    unawaited(_controller.reverse());
    setState(() {});
    if (value != widget.selected) {
      widget.onChanged(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.options.firstWhere(
      (option) => option.value == widget.selected,
      orElse: () => widget.options.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          key: const ValueKey('section-dropdown-header'),
          option: current,
          expand: _expand,
          onTap: _toggle,
        ),
        // A fully collapsed panel leaves the tree entirely: otherwise its
        // rows stay findable by screen readers and tests while being
        // invisible and unhittable.
        AnimatedBuilder(
          animation: _expand,
          builder: (context, child) => _expand.value == 0
              ? const SizedBox.shrink()
              : SizeTransition(
                  sizeFactor: _expand,
                  alignment: AlignmentDirectional.topCenter,
                  child: FadeTransition(opacity: _expand, child: child),
                ),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              key: const ValueKey('section-dropdown-panel'),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.hairline),
              ),
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  for (var index = 0; index < widget.options.length; index++)
                    _OptionRow(
                      option: widget.options[index],
                      selected: widget.options[index].value == widget.selected,
                      // Each row slides in a beat after the one above it,
                      // so the list unfurls instead of appearing at once.
                      animation: CurvedAnimation(
                        parent: _expand,
                        curve: Interval(
                          (index / widget.options.length) * 0.5,
                          1,
                          curve: AppMotion.standard,
                        ),
                      ),
                      onTap: () => _pick(widget.options[index].value),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.option,
    required this.expand,
    required this.onTap,
    super.key,
  });

  final SectionOption<Object?> option;
  final Animation<double> expand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Раздел: ${option.label}',
      child: Material(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.capsule),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.capsule),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.capsule),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                Icon(option.icon, size: 20, color: AppColors.primaryInk),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.settingsRowTitle.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (option.count case final count? when count > 0) ...[
                  _CountBadge(count: count),
                  const SizedBox(width: 10),
                ],
                RotationTransition(
                  turns: Tween<double>(begin: 0, end: 0.5).animate(expand),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 24,
                    color: AppColors.secondaryInk,
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

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.animation,
    required this.onTap,
  });

  final SectionOption<Object?> option;
  final bool selected;
  final Animation<double> animation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.18),
          end: Offset.zero,
        ).animate(animation),
        child: Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: selected ? AppColors.accentBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.settingsTile),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadii.settingsTile),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      option.icon,
                      size: 19,
                      color: selected ? Colors.white : AppColors.secondaryInk,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.settingsRowTitle.copyWith(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected ? Colors.white : AppColors.primaryInk,
                        ),
                      ),
                    ),
                    if (option.count case final count? when count > 0)
                      _CountBadge(count: count, onDark: selected),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, this.onDark = false});

  final int count;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.22)
            : AppColors.pageSurface,
        borderRadius: BorderRadius.circular(AppRadii.capsule),
      ),
      child: Text(
        '$count',
        style: AppTypography.routeMetadata.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: onDark ? Colors.white : AppColors.secondaryInk,
        ),
      ),
    );
  }
}
