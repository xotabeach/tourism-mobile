import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';

class AppSearchFilterRow extends StatelessWidget {
  const AppSearchFilterRow({
    required this.onSearchTap,
    required this.onFilterTap,
    super.key,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AppGlassSurface(
              borderRadius: AppRadii.field,
              blur: 10,
              fillColor: Colors.white.withValues(alpha: 0.18),
              borderColor: const Color(0xFFD3D3D6),
              borderWidth: 1.4,
              boxShadow: const [],
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.field),
                  onTap: onSearchTap,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        AppAssetIcon(
                          AppIconography.search,
                          size: 30,
                          color: AppColors.secondaryInk,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Искать маршруты и места',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
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
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppGlassIconButton(
            iconAsset: AppIconography.filter,
            semanticLabel: 'Фильтры',
            onPressed: onFilterTap,
            dimension: 58,
            iconSize: 28,
            fillColor: AppColors.glassFillStrong,
          ),
        ],
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
      height: 40,
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            if (index > 0) const SizedBox(width: AppSpacing.xs),
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
