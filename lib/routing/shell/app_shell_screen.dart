import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';

class AppShellScreen extends StatelessWidget {
  const AppShellScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          navigationShell,
          Positioned(
            left: AppSpacing.floatingNavInset,
            right: AppSpacing.floatingNavInset,
            bottom: bottomInset > 0 ? bottomInset : AppSpacing.sm,
            child: AppFloatingNavBar(
              currentIndex: navigationShell.currentIndex,
              onTap: _onDestinationSelected,
            ),
          ),
        ],
      ),
    );
  }
}

class AppFloatingNavBar extends StatefulWidget {
  const AppFloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  State<AppFloatingNavBar> createState() => _AppFloatingNavBarState();
}

class _AppFloatingNavBarState extends State<AppFloatingNavBar>
    with SingleTickerProviderStateMixin {
  static const _height = 58.0;
  static const _activeDiameter = 58.0;
  static const _segmentGap = 10.0;

  static const _destinations = [
    _NavDestination(
      label: 'Главная',
      icon: AppIconography.home,
      selectedIcon: AppIconography.home,
    ),
    _NavDestination(
      label: 'Маршруты',
      icon: AppIconography.routes,
      selectedIcon: AppIconography.routes,
    ),
    _NavDestination(
      label: 'Подобрать',
      icon: AppIconography.build,
      selectedIcon: AppIconography.build,
    ),
    _NavDestination(
      label: 'Карта',
      icon: AppIconography.map,
      selectedIcon: AppIconography.map,
    ),
    _NavDestination(
      label: 'Профиль',
      icon: AppIconography.profile,
      selectedIcon: AppIconography.profileSelected,
    ),
  ];

  late final AnimationController _controller;
  late double _position;
  late double _fromPosition;
  late int _targetIndex;

  @override
  void initState() {
    super.initState();
    _position = widget.currentIndex.toDouble();
    _fromPosition = _position;
    _targetIndex = widget.currentIndex;
    _controller = AnimationController(vsync: this, duration: AppMotion.droplet)
      ..addListener(_tick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _position = _targetIndex.toDouble();
        }
      });
  }

  @override
  void didUpdateWidget(covariant AppFloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != _targetIndex) {
      _animateTo(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_tick)
      ..dispose();
    super.dispose();
  }

  void _tick() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final curve = reduceMotion
        ? Curves.easeOut
        : Curves.easeInOutCubicEmphasized;
    final eased = curve.transform(_controller.value);
    setState(() {
      _position = lerpDouble(_fromPosition, _targetIndex.toDouble(), eased)!;
    });
  }

  void _animateTo(int index) {
    if (index == _targetIndex && !_controller.isAnimating) {
      return;
    }
    _controller.stop();
    _fromPosition = _position;
    _targetIndex = index;
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? AppMotion.reduced
        : AppMotion.droplet;
    unawaited(_controller.forward(from: 0));
  }

  void _handleTap(int index) {
    if (index != widget.currentIndex) {
      unawaited(HapticFeedback.selectionClick());
      _animateTo(index);
    }
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final phase = _controller.isAnimating ? _controller.value : 1.0;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: _height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final slotWidth = width / _destinations.length;
            final activeCenterX = (_position + 0.5) * slotWidth;
            final fromCenterX = (_fromPosition + 0.5) * slotWidth;
            final leadingWidth = math.max(
              0.0,
              _position * slotWidth - _segmentGap / 2,
            );
            final trailingLeft = math.min(
              width,
              (_position + 1) * slotWidth + _segmentGap / 2,
            );

            return FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (leadingWidth > 1)
                    Positioned(
                      left: 0,
                      top: 0,
                      width: leadingWidth,
                      height: _height,
                      child: const AppGlassSurface(
                        borderRadius: AppRadii.capsule,
                        blur: 20,
                        fillColor: AppColors.glassFillStrong,
                        borderColor: AppColors.glassBorder,
                        child: SizedBox.expand(),
                      ),
                    ),
                  if (trailingLeft < width - 1)
                    Positioned(
                      left: trailingLeft,
                      right: 0,
                      top: 0,
                      height: _height,
                      child: const AppGlassSurface(
                        borderRadius: AppRadii.capsule,
                        blur: 20,
                        fillColor: AppColors.glassFillStrong,
                        borderColor: AppColors.glassBorder,
                        child: SizedBox.expand(),
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _DropletPainter(
                            centerX: activeCenterX,
                            fromCenterX: fromCenterX,
                            centerY: _height / 2,
                            diameter: _activeDiameter,
                            phase: phase,
                            reduceMotion: reduceMotion,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      children: [
                        for (
                          var index = 0;
                          index < _destinations.length;
                          index++
                        )
                          SizedBox(
                            width: slotWidth,
                            height: _height,
                            child: _NavItem(
                              destination: _destinations[index],
                              index: index,
                              activeWeight: (1 - (_position - index).abs())
                                  .clamp(0, 1),
                              onTap: _handleTap,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String icon;
  final String selectedIcon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.index,
    required this.activeWeight,
    required this.onTap,
  });

  final _NavDestination destination;
  final int index;
  final double activeWeight;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = activeWeight > 0.99;
    final inactiveColor = AppColors.inactiveNavigationIcon.withValues(
      alpha: 0.84,
    );

    return Semantics(
      label: destination.label,
      button: true,
      selected: selected,
      sortKey: OrdinalSortKey(index.toDouble()),
      child: Tooltip(
        message: destination.label,
        child: InkResponse(
          onTap: () => onTap(index),
          radius: 30,
          containedInkWell: true,
          highlightShape: BoxShape.circle,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AppAssetIcon(
                  destination.icon,
                  size: AppIconography.navigation,
                  color: inactiveColor.withValues(
                    alpha: inactiveColor.a * (1 - activeWeight),
                  ),
                ),
                AppAssetIcon(
                  destination.selectedIcon,
                  size: AppIconography.navigation,
                  color: Colors.white.withValues(alpha: activeWeight),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DropletPainter extends CustomPainter {
  const _DropletPainter({
    required this.centerX,
    required this.fromCenterX,
    required this.centerY,
    required this.diameter,
    required this.phase,
    required this.reduceMotion,
  });

  final double centerX;
  final double fromCenterX;
  final double centerY;
  final double diameter;
  final double phase;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = AppColors.activeNavigationFill
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    if (!reduceMotion && phase < 0.3 && fromCenterX != centerX) {
      final neck = 1 - phase / 0.3;
      final left = math.min(fromCenterX, centerX);
      final right = math.max(fromCenterX, centerX);
      final neckRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(left, centerY - 10 * neck, right, centerY + 10 * neck),
        Radius.circular(10 * neck),
      );
      canvas.drawRRect(neckRect, fill);
      canvas.drawCircle(
        Offset(fromCenterX, centerY),
        diameter / 2 * (0.96 - phase * 0.12),
        fill,
      );
    }

    final stretch = reduceMotion ? 0.0 : math.sin(math.pi * phase).abs();
    final width = diameter * (1 + 0.14 * stretch);
    final height = diameter * (1 - 0.1 * stretch);
    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: width,
      height: height,
    );
    final droplet = RRect.fromRectAndRadius(rect, Radius.circular(height / 2));
    canvas
      ..drawRRect(droplet.shift(const Offset(0, 3)), shadow)
      ..drawRRect(droplet, fill)
      ..drawRRect(droplet, stroke);
  }

  @override
  bool shouldRepaint(covariant _DropletPainter oldDelegate) {
    return oldDelegate.centerX != centerX ||
        oldDelegate.fromCenterX != fromCenterX ||
        oldDelegate.phase != phase ||
        oldDelegate.reduceMotion != reduceMotion;
  }
}
