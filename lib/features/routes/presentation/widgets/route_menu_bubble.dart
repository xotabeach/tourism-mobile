import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

/// One row inside [showRouteMenuBubble].
class RouteMenuAction {
  const RouteMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
}

/// Menu that grows out of its anchor button instead of sliding up from the
/// bottom edge.
///
/// The bubble's right edge is pinned to the anchor's left edge and it scales
/// from that corner, so the motion reads as the round button unfolding into a
/// panel rather than as an unrelated sheet appearing. Falls back to opening
/// rightwards when the anchor sits too close to the left edge to fit.
Future<void> showRouteMenuBubble({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<RouteMenuAction> actions,
}) {
  final anchorBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  final overlayBox =
      Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
  if (anchorBox == null || overlayBox == null) {
    return Future<void>.value();
  }
  final anchorTopLeft = anchorBox.localToGlobal(
    Offset.zero,
    ancestor: overlayBox,
  );
  final anchorRect = anchorTopLeft & anchorBox.size;
  final overlaySize = overlayBox.size;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть меню маршрута',
    barrierColor: const Color(0x33000000),
    transitionDuration: AppMotion.emphasized,
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (dialogContext, animation, _, _) {
      return _RouteMenuBubble(
        animation: animation,
        anchorRect: anchorRect,
        overlaySize: overlaySize,
        actions: actions,
      );
    },
  );
}

class _RouteMenuBubble extends StatelessWidget {
  const _RouteMenuBubble({
    required this.animation,
    required this.anchorRect,
    required this.overlaySize,
    required this.actions,
  });

  static const double _width = 264;
  static const double _gap = 10;

  final Animation<double> animation;
  final Rect anchorRect;
  final Size overlaySize;
  final List<RouteMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    // Prefer growing leftwards out of the button; flip only when that would
    // run past the screen edge.
    final leftIfBefore = anchorRect.left - _gap - _width;
    final opensLeft = leftIfBefore >= 12;
    final left = opensLeft ? leftIfBefore : anchorRect.right + _gap;
    final clampedLeft = left.clamp(12.0, overlaySize.width - _width - 12);

    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.emphasizedCurve,
      reverseCurve: Curves.easeInCubic,
    );

    // Estimated bubble height keeps it on-screen without a layout pass.
    final estimatedHeight = actions.length * 52.0 + 16;
    final maxTop = overlaySize.height - padding.bottom - estimatedHeight - 12;
    final top = (anchorRect.center.dy - estimatedHeight / 2).clamp(
      padding.top + 12,
      maxTop < padding.top + 12 ? padding.top + 12 : maxTop,
    );

    return Stack(
      children: [
        Positioned(
          left: clampedLeft,
          top: top,
          width: _width,
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.72, end: 1).animate(curved),
              // Scale out of the edge nearest the button so the panel appears
              // to unfold from it.
              alignment: opensLeft
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Material(
                color: AppColors.elevatedSurface,
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                elevation: 12,
                shadowColor: const Color(0x33000000),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    for (final action in actions)
                      InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          action.onSelected();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                action.icon,
                                size: 20,
                                color: AppColors.primaryInk,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  action.label,
                                  style: AppTypography.settingsRowTitle
                                      .copyWith(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
