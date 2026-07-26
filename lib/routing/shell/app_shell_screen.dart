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
import 'package:tourism_mobile/features/routes/presentation/widgets/route_media_header.dart';

const _appNavDestinations = [
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

final _appFloatingNavKey = GlobalKey<_AppFloatingNavBarState>(
  debugLabel: 'app-floating-navigation',
);

class AppShellScreen extends StatelessWidget {
  const AppShellScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  bool _showRouteDetailsChrome(BuildContext context) {
    final location = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;
    final segments = Uri.parse(location).pathSegments;
    return segments.length == 2 && segments.first == 'routes';
  }

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _startRoute(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Прохождение маршрута появится позже')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final showRouteDetailsChrome = _showRouteDetailsChrome(context);

    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          navigationShell,
          if (showRouteDetailsChrome)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomInset + 156,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00FFFFFF),
                        Color(0xF2FFFFFF),
                        AppColors.elevatedSurface,
                      ],
                      stops: [0, 0.46, 1],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: AppSpacing.floatingNavInset,
            right: AppSpacing.floatingNavInset,
            bottom: bottomInset > 0 ? bottomInset : AppSpacing.sm,
            child: AppFloatingNavBar(
              key: _appFloatingNavKey,
              currentIndex: navigationShell.currentIndex,
              onTap: _onDestinationSelected,
              detailMode: showRouteDetailsChrome,
              onStartRoute: () => _startRoute(context),
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
    this.detailMode = false,
    this.onStartRoute,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool detailMode;
  final VoidCallback? onStartRoute;

  @override
  State<AppFloatingNavBar> createState() => _AppFloatingNavBarState();
}

class _AppFloatingNavBarState extends State<AppFloatingNavBar>
    with TickerProviderStateMixin {
  static const _height = 58.0;
  static const _detailHeight = 126.0;
  static const _activeDiameter = 58.0;
  static const _segmentGap = 10.0;

  late final AnimationController _positionController;
  late final AnimationController _detailPresenceController;
  late final AnimationController _detailExpansionController;
  late double _position;
  late double _fromPosition;
  late int _targetIndex;

  @override
  void initState() {
    super.initState();
    _position = widget.currentIndex.toDouble();
    _fromPosition = _position;
    _targetIndex = widget.currentIndex;
    _positionController =
        AnimationController(vsync: this, duration: AppMotion.droplet)
          ..addListener(_tick)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _position = _targetIndex.toDouble();
            }
          });
    _detailPresenceController = AnimationController(
      vsync: this,
      duration: AppMotion.detailMorph,
      value: widget.detailMode ? 1 : 0,
    )..addListener(_rebuild);
    _detailExpansionController = AnimationController(
      vsync: this,
      duration: AppMotion.detailMorph,
    )..addListener(_rebuild);
    if (widget.detailMode) {
      _position = 0;
      _fromPosition = 0;
      _targetIndex = 0;
    }
  }

  @override
  void didUpdateWidget(covariant AppFloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.detailMode != oldWidget.detailMode) {
      if (widget.detailMode) {
        _detailExpansionController.value = 0;
        _animateTo(0);
        _animateDetailPresence(1);
      } else {
        _animateTo(widget.currentIndex);
        _animateDetailPresence(0);
      }
    } else if (!widget.detailMode && widget.currentIndex != _targetIndex) {
      _animateTo(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _positionController
      ..removeListener(_tick)
      ..dispose();
    _detailPresenceController
      ..removeListener(_rebuild)
      ..dispose();
    _detailExpansionController
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _tick() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final curve = reduceMotion
        ? Curves.easeOut
        : Curves.easeInOutCubicEmphasized;
    final eased = curve.transform(_positionController.value);
    setState(() {
      _position = lerpDouble(_fromPosition, _targetIndex.toDouble(), eased)!;
    });
  }

  void _animateTo(int index) {
    if (index == _targetIndex && !_positionController.isAnimating) {
      return;
    }
    _positionController.stop();
    _fromPosition = _position;
    _targetIndex = index;
    _positionController.duration = MediaQuery.disableAnimationsOf(context)
        ? AppMotion.reduced
        : AppMotion.droplet;
    unawaited(_positionController.forward(from: 0));
  }

  void _animateDetailPresence(double target) {
    _detailPresenceController.duration = MediaQuery.disableAnimationsOf(context)
        ? AppMotion.reduced
        : AppMotion.detailMorph;
    unawaited(
      _detailPresenceController.animateTo(
        target,
        curve: MediaQuery.disableAnimationsOf(context)
            ? Curves.easeOut
            : AppMotion.emphasizedCurve,
      ),
    );
  }

  void _expandDetailNavigation() {
    if (!widget.detailMode || _detailExpansionController.value >= 1) {
      return;
    }
    _detailExpansionController.duration =
        MediaQuery.disableAnimationsOf(context)
        ? AppMotion.reduced
        : AppMotion.detailMorph;
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      _detailExpansionController.forward().then((_) {
        if (mounted) {
          setState(() {});
        }
      }),
    );
  }

  void _handleTap(int index) {
    if (widget.detailMode &&
        _detailExpansionController.value < 1 &&
        index == 0) {
      _expandDetailNavigation();
      return;
    }
    if (index != widget.currentIndex) {
      unawaited(HapticFeedback.selectionClick());
      _animateTo(index);
    }
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final phase = _positionController.isAnimating
        ? _positionController.value
        : 1.0;
    final presence = _detailPresenceController.value;
    final expanded = _detailExpansionController.value;
    final compactProgress = presence * (1 - expanded);
    final showDetailLayout =
        widget.detailMode ||
        _detailPresenceController.isAnimating ||
        presence > 0.001;
    final totalHeight = showDetailLayout ? _detailHeight : _height;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        key: const ValueKey('app-shell-bottom-bar'),
        height: totalHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final ctaMorph = Curves.easeInOutCubic.transform(compactProgress);
            final ctaLeft = (_activeDiameter + _segmentGap) * ctaMorph;
            final ctaTop = (_detailHeight - _height) * ctaMorph;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (widget.detailMode && widget.onStartRoute != null)
                  Positioned(
                    key: const ValueKey('route-start-button-position'),
                    left: ctaLeft,
                    right: 0,
                    top: ctaTop,
                    height: _height,
                    child: RouteStartButton(
                      visibility: presence,
                      morphProgress: ctaMorph,
                      onPressed: widget.onStartRoute!,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _height,
                  child: _buildNavigation(
                    width: width,
                    compactProgress: compactProgress,
                    phase: phase,
                    reduceMotion: reduceMotion,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavigation({
    required double width,
    required double compactProgress,
    required double phase,
    required bool reduceMotion,
  }) {
    final slotWidth = width / _appNavDestinations.length;
    final regularActiveCenterX = (_position + 0.5) * slotWidth;
    final regularFromCenterX = (_fromPosition + 0.5) * slotWidth;
    const compactCenterX = _activeDiameter / 2;
    final activeCenterX = lerpDouble(
      regularActiveCenterX,
      compactCenterX,
      compactProgress,
    )!;
    final fromCenterX = lerpDouble(
      regularFromCenterX,
      compactCenterX,
      compactProgress,
    )!;
    final regularLeadingEnd = math.max(
      0.0,
      _position * slotWidth - _segmentGap / 2,
    );
    final leadingStart = lerpDouble(0, compactCenterX, compactProgress)!;
    final leadingEnd = lerpDouble(
      regularLeadingEnd,
      compactCenterX,
      compactProgress,
    )!;
    final regularTrailingLeft = math.min(
      width,
      (_position + 1) * slotWidth + _segmentGap / 2,
    );
    final trailingStart = lerpDouble(
      regularTrailingLeft,
      compactCenterX,
      compactProgress,
    )!;
    final trailingEnd = lerpDouble(width, compactCenterX, compactProgress)!;
    final revealProgress = 1 - compactProgress;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if ((leadingEnd - leadingStart).abs() > 1)
            Positioned(
              left: math.min(leadingStart, leadingEnd),
              top: 0,
              width: (leadingEnd - leadingStart).abs(),
              height: _height,
              child: const AppGlassSurface(
                borderRadius: AppRadii.capsule,
                blur: 20,
                fillColor: AppColors.glassFillStrong,
                borderColor: AppColors.glassBorder,
                child: SizedBox.expand(),
              ),
            ),
          if ((trailingEnd - trailingStart).abs() > 1)
            Positioned(
              left: math.min(trailingStart, trailingEnd),
              width: (trailingEnd - trailingStart).abs(),
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
            child: IgnorePointer(
              ignoring: compactProgress > 0.995,
              child: Row(
                children: [
                  for (
                    var index = 0;
                    index < _appNavDestinations.length;
                    index++
                  )
                    SizedBox(
                      width: slotWidth,
                      height: _height,
                      child: _NavItem(
                        destination: _appNavDestinations[index],
                        index: index,
                        activeWeight: (1 - (_position - index).abs()).clamp(
                          0,
                          1,
                        ),
                        visibility: index == 0
                            ? 1
                            : ((revealProgress - (index - 1) * 0.055) / 0.78)
                                  .clamp(0, 1),
                        translationX:
                            (compactCenterX - (index + 0.5) * slotWidth) *
                            compactProgress,
                        onTap: _handleTap,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (compactProgress > 0.995)
            Positioned(
              left: 0,
              top: 0,
              width: _activeDiameter,
              height: _height,
              child: Semantics(
                label: 'Развернуть навигацию, выбран раздел Главная',
                button: true,
                selected: true,
                child: Tooltip(
                  message: 'Развернуть навигацию',
                  child: GestureDetector(
                    key: const ValueKey('expand-route-details-navigation'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _expandDetailNavigation,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
        ],
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
    this.visibility = 1,
    this.translationX = 0,
    required this.onTap,
  });

  final _NavDestination destination;
  final int index;
  final double activeWeight;
  final double visibility;
  final double translationX;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = activeWeight > 0.99;
    final inactiveColor = AppColors.inactiveNavigationIcon.withValues(
      alpha: 0.84 * visibility,
    );

    return ExcludeSemantics(
      excluding: visibility < 0.99,
      child: IgnorePointer(
        ignoring: visibility < 0.99,
        child: Transform.translate(
          offset: Offset(translationX, 0),
          child: Semantics(
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
                        color: Colors.white.withValues(
                          alpha: activeWeight * visibility,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
      final neckStrength = 1 - phase / 0.3;
      final travel = centerX - fromCenterX;
      final distance = travel.abs();
      final direction = travel.sign;
      final tailLength = math.min(distance, diameter * 0.62);
      final tailX = centerX - direction * tailLength;
      final left = math.min(tailX, centerX);
      final right = math.max(tailX, centerX);
      final oldVisibility = (1 - distance / (diameter * 0.9)).clamp(0.0, 1.0);
      final tailHalfHeight = 10 * neckStrength * (0.82 + 0.18 * oldVisibility);
      final neckRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          left,
          centerY - tailHalfHeight,
          right,
          centerY + tailHalfHeight,
        ),
        Radius.circular(tailHalfHeight),
      );
      canvas.drawRRect(neckRect, fill);
      final oldRadius = diameter / 2 * (0.96 - phase * 0.12) * oldVisibility;
      if (oldRadius > 0.5) {
        canvas.drawCircle(Offset(fromCenterX, centerY), oldRadius, fill);
      }
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
