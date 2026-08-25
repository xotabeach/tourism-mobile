import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

class AppSearchFilterRow extends StatelessWidget {
  const AppSearchFilterRow({
    required this.onFilterTap,
    this.onSearchTap,
    this.controller,
    this.focusNode,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchClear,
    this.onSearchDismiss,
    this.resetOnUnfocus = false,
    this.filterApplied = false,
    this.hintText = 'Искать маршруты и места',
    super.key,
  }) : assert(onSearchTap != null || onSearchChanged != null);

  final VoidCallback onFilterTap;
  final VoidCallback? onSearchTap;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onSearchClear;
  final VoidCallback? onSearchDismiss;
  final bool resetOnUnfocus;
  final bool filterApplied;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final searchField = controller == null
        ? InkWell(
            borderRadius: BorderRadius.circular(AppRadii.field),
            onTap: onSearchTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _SearchPlaceholder(hintText: hintText),
            ),
          )
        : _ActiveSearchField(
            controller: controller!,
            focusNode: focusNode,
            hintText: hintText,
            onSearchChanged: onSearchChanged,
            onSearchSubmitted: onSearchSubmitted,
            onSearchClear: onSearchClear,
            onSearchDismiss: onSearchDismiss,
            resetOnUnfocus: resetOnUnfocus,
          );

    return SizedBox(
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Material(
              color: AppColors.controlSurface,
              borderRadius: BorderRadius.circular(AppRadii.field),
              child: searchField,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          AppFlatIconButton(
            iconAsset: AppIconography.filter,
            semanticLabel: 'Фильтры',
            onPressed: onFilterTap,
            iconOverride: filterApplied ? Icons.check_rounded : null,
          ),
        ],
      ),
    );
  }
}

class _ActiveSearchField extends StatefulWidget {
  const _ActiveSearchField({
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchClear,
    this.onSearchDismiss,
    this.resetOnUnfocus = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onSearchClear;
  final VoidCallback? onSearchDismiss;
  final bool resetOnUnfocus;

  @override
  State<_ActiveSearchField> createState() => _ActiveSearchFieldState();
}

class _ActiveSearchFieldState extends State<_ActiveSearchField> {
  late final FocusNode _focusNode;
  var _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'app-search-field');
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _ActiveSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      _ownsFocusNode = widget.focusNode == null;
      _focusNode =
          widget.focusNode ?? FocusNode(debugLabel: 'app-search-field');
      _focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      if (widget.resetOnUnfocus) {
        _resetQuery();
      }
      widget.onSearchDismiss?.call();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _resetQuery() {
    if (widget.controller.text.isEmpty) {
      return;
    }
    widget.controller.clear();
    if (widget.onSearchClear != null) {
      widget.onSearchClear!();
    } else {
      widget.onSearchChanged?.call('');
    }
  }

  void _dismissFocus() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
      return;
    }
    if (widget.resetOnUnfocus) {
      _resetQuery();
      widget.onSearchDismiss?.call();
    }
  }

  void _dismissOrClear() {
    _resetQuery();
    _dismissFocus();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    final showClose = hasText || _focusNode.hasFocus;

    return TapRegion(
      onTapOutside: (_) => _dismissFocus(),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onSearchChanged,
        onSubmitted: widget.onSearchSubmitted,
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
          hintText: widget.hintText,
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
                  tooltip: hasText ? 'Очистить поиск' : 'Закрыть поиск',
                  onPressed: _dismissOrClear,
                  icon: const Icon(Icons.close_rounded, size: 20),
                )
              : null,
        ),
      ),
    );
  }
}

class _SearchPlaceholder extends StatelessWidget {
  const _SearchPlaceholder({required this.hintText});

  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppAssetIcon(
          AppIconography.search,
          size: 24,
          color: AppColors.secondaryInk,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            hintText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.2,
              letterSpacing: 0,
              color: AppColors.secondaryInk,
            ),
          ),
        ),
      ],
    );
  }
}

/// Flat circular control used for the bell and filter buttons on light pages.
class AppFlatIconButton extends StatelessWidget {
  const AppFlatIconButton({
    required this.iconAsset,
    required this.semanticLabel,
    required this.onPressed,
    this.dimension = 48,
    this.iconSize = 24,
    this.color = AppColors.primaryInk,
    this.badgeCount = 0,
    this.iconOverride,
    super.key,
  });

  final String iconAsset;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double dimension;
  final double iconSize;
  final Color color;

  /// Unread / status count drawn top-right. Hidden when `<= 0`.
  final int badgeCount;
  final IconData? iconOverride;

  static String formatBadgeCount(int count) {
    if (count <= 0) {
      return '';
    }
    if (count > 99) {
      return '99+';
    }
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    final badge = formatBadgeCount(badgeCount);
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onPressed != null,
      child: Tooltip(
        message: semanticLabel,
        child: SizedBox.square(
          dimension: dimension,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Material(
                  color: AppColors.controlSurface,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onPressed,
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: iconOverride != null
                          ? Icon(iconOverride, size: iconSize, color: color)
                          : AppAssetIcon(
                              iconAsset,
                              size: iconSize,
                              color: color,
                            ),
                    ),
                  ),
                ),
              ),
              if (badge.isNotEmpty)
                Positioned(
                  top: 2,
                  right: 2,
                  child: IgnorePointer(
                    child: Container(
                      key: const ValueKey('app-flat-icon-badge'),
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.all(Radius.circular(9)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppFilterChipBar extends StatelessWidget {
  const AppFilterChipBar({
    required this.labels,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return SizedBox(
      height: 37,
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            if (index > 0) const SizedBox(width: AppSpacing.xxs + 2),
            Expanded(
              child: Semantics(
                selected: labels[index] == selected,
                button: true,
                label: 'Фильтр ${labels[index]}',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    onTap: () => onSelected(labels[index]),
                    child: AnimatedContainer(
                      duration: reduceMotion
                          ? AppMotion.reduced
                          : AppMotion.normal,
                      curve: AppMotion.standard,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: labels[index] == selected
                            ? AppColors.primaryInk
                            : Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                        border: Border.all(
                          color: labels[index] == selected
                              ? AppColors.primaryInk
                              : const Color(0xFFDADADD),
                        ),
                      ),
                      child: Text(
                        labels[index],
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: AppTypography.chip.copyWith(
                          color: labels[index] == selected
                              ? Colors.white
                              : AppColors.primaryInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact 2+-option segmented pill (e.g. Маршруты/Локации on Home), distinct
/// from [AppFilterChipBar]'s N equal-width category chips: a single rounded
/// track with one filled selected segment, not independently bordered chips.
class AppSegmentedToggle extends StatelessWidget {
  const AppSegmentedToggle({
    required this.labels,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.controlSurface,
        borderRadius: BorderRadius.circular(AppRadii.capsule),
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            if (index > 0) const SizedBox(width: 3),
            Expanded(
              child: Semantics(
                selected: labels[index] == selected,
                button: true,
                label: labels[index],
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.capsule),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.capsule),
                    onTap: () => onSelected(labels[index]),
                    child: AnimatedContainer(
                      duration: reduceMotion
                          ? AppMotion.reduced
                          : AppMotion.normal,
                      curve: AppMotion.standard,
                      alignment: Alignment.center,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: labels[index] == selected
                            ? AppColors.primaryInk
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.capsule),
                      ),
                      child: Text(
                        labels[index],
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: AppTypography.chip.copyWith(
                          color: labels[index] == selected
                              ? Colors.white
                              : AppColors.primaryInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppPressableScale extends StatefulWidget {
  const AppPressableScale({
    required this.child,
    required this.onTap,
    this.borderRadius = AppRadii.card,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  State<AppPressableScale> createState() => _AppPressableScaleState();
}

class _AppPressableScaleState extends State<AppPressableScale> {
  var _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.onTap == null) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedScale(
      scale: _pressed && !reduceMotion ? 0.985 : 1,
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          onTap: widget.onTap,
          onHighlightChanged: _setPressed,
          child: widget.child,
        ),
      ),
    );
  }
}
