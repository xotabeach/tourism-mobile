import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/routing/app_router.dart';

enum RouteSwipeAction { favorite, skip }

/// Responsive swipe stack with deterministic progress rendering for goldens.
class RouteSwipeDeck extends StatefulWidget {
  const RouteSwipeDeck({
    required this.routes,
    this.onSwipe,
    this.showCoach = false,
    this.onCoachDismiss,
    this.debugProgress,
    super.key,
  });

  final List<RouteSummary> routes;
  final void Function(RouteSummary route, RouteSwipeAction action)? onSwipe;
  final bool showCoach;
  final VoidCallback? onCoachDismiss;

  /// Test-only visual state. Values are clamped to -1...1.
  final double? debugProgress;

  @override
  State<RouteSwipeDeck> createState() => _RouteSwipeDeckState();
}

class _RouteSwipeDeckState extends State<RouteSwipeDeck>
    with SingleTickerProviderStateMixin {
  static const double _swipeThreshold = 118;
  static const double _dragTravelFactor = 0.34;
  static const double _maxHeldDrag = _swipeThreshold * 1.1;
  static const double _maxAngle = math.pi / 20;

  late List<RouteSummary> _deck;
  late final AnimationController _motionController;
  Animation<Offset>? _offsetAnimation;
  Offset _dragOffset = Offset.zero;
  RouteSwipeAction? _pendingAction;
  var _dragging = false;

  @override
  void initState() {
    super.initState();
    _deck = List<RouteSummary>.from(widget.routes);
    _motionController = AnimationController(
      vsync: this,
      duration: AppMotion.emphasized,
    )..addStatusListener(_handleMotionStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheDeckImages();
  }

  @override
  void didUpdateWidget(covariant RouteSwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routes != widget.routes) {
      _deck = List<RouteSummary>.from(widget.routes);
      _resetMotion();
      _precacheDeckImages();
    }
  }

  void _precacheDeckImages() {
    for (final route in _deck.take(3)) {
      final path = route.coverImageUrl;
      if (AppImages.isAssetPath(path)) {
        unawaited(precacheImage(AssetImage(path!), context));
      }
    }
  }

  @override
  void dispose() {
    _motionController
      ..removeStatusListener(_handleMotionStatus)
      ..dispose();
    super.dispose();
  }

  void _handleMotionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    if (_pendingAction != null) {
      _finishSwipe();
      return;
    }
    setState(_resetMotion);
  }

  void _resetMotion() {
    _motionController.reset();
    _offsetAnimation = null;
    _dragOffset = Offset.zero;
    _pendingAction = null;
    _dragging = false;
  }

  void _onPanStart(DragStartDetails _) {
    if (_motionController.isAnimating ||
        _deck.isEmpty ||
        widget.showCoach ||
        widget.debugProgress != null) {
      return;
    }
    setState(() => _dragging = true);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_dragging || _motionController.isAnimating) {
      return;
    }
    setState(() {
      _dragOffset = Offset(
        (_dragOffset.dx + details.delta.dx).clamp(-_maxHeldDrag, _maxHeldDrag),
        0,
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_dragging || _motionController.isAnimating) {
      return;
    }
    final velocityX = details.velocity.pixelsPerSecond.dx;
    final shouldFavorite = _dragOffset.dx > _swipeThreshold || velocityX > 850;
    final shouldSkip = _dragOffset.dx < -_swipeThreshold || velocityX < -850;

    if (shouldFavorite) {
      _commitSwipe(RouteSwipeAction.favorite);
    } else if (shouldSkip) {
      _commitSwipe(RouteSwipeAction.skip);
    } else {
      _springBack();
    }
  }

  void _springBack() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _pendingAction = null;
    _dragging = false;
    _motionController.duration = reduceMotion
        ? AppMotion.reduced
        : const Duration(milliseconds: 340);
    _offsetAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _motionController,
            curve: reduceMotion ? AppMotion.standard : AppMotion.spring,
          ),
        );
    unawaited(_motionController.forward(from: 0));
  }

  void _commitSwipe(RouteSwipeAction action) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final width = MediaQuery.sizeOf(context).width;
    _pendingAction = action;
    _dragging = false;
    unawaited(HapticFeedback.mediumImpact());
    _motionController.duration = reduceMotion
        ? AppMotion.reduced
        : AppMotion.emphasized;
    _offsetAnimation =
        Tween<Offset>(
          begin: _dragOffset,
          end: Offset(
            action == RouteSwipeAction.favorite ? width * 1.45 : -width * 1.45,
            0,
          ),
        ).animate(
          CurvedAnimation(parent: _motionController, curve: Curves.easeInCubic),
        );
    unawaited(_motionController.forward(from: 0));
  }

  void _finishSwipe() {
    if (_deck.isEmpty || _pendingAction == null) {
      return;
    }
    final route = _deck.removeAt(0);
    final action = _pendingAction!;
    widget.onSwipe?.call(route, action);
    if (action == RouteSwipeAction.skip) {
      _deck.add(route);
    }
    setState(_resetMotion);
  }

  void _openDetails(RouteSummary route) {
    if (_motionController.isAnimating ||
        widget.showCoach ||
        widget.debugProgress != null) {
      return;
    }
    unawaited(
      context.pushNamed(
        AppRouteNames.routeDetails,
        pathParameters: {'id': route.id},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_deck.isEmpty) {
      return const Center(child: Text('Маршруты закончились'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth - AppSpacing.page * 2;
        final desiredHeight = cardWidth * 1.43;
        final maxUsableHeight = math.max(320.0, constraints.maxHeight - 104);
        final cardHeight = math.min(desiredHeight, maxUsableHeight);

        return AnimatedBuilder(
          animation: _motionController,
          builder: (context, _) {
            final debugProgress = widget.debugProgress?.clamp(-1.0, 1.0);
            final rawOffset = debugProgress != null
                ? Offset(debugProgress * _swipeThreshold, 0)
                : (_offsetAnimation?.value ?? _dragOffset);
            final progress = debugProgress ?? _progressFor(rawOffset.dx);
            final promotion = progress.abs();
            final angle = _maxAngle * progress;
            final topOffset = Offset(
              _visualTravelFor(
                rawOffset.dx,
                committing: _pendingAction != null,
              ),
              0,
            );
            final backIndex = widget.showCoach ? 0 : 1;
            final farBackIndex = widget.showCoach ? 1 : 2;

            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                96,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: cardWidth,
                  height: cardHeight + 18,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (_deck.length > farBackIndex)
                        Positioned(
                          top: -14,
                          left: 0,
                          right: 0,
                          height: cardHeight,
                          child: _BackCard(
                            route: _deck[farBackIndex],
                            scale: 0.93 + promotion * 0.02,
                            opacity: 0.42 + promotion * 0.18,
                          ),
                        ),
                      if (_deck.length > backIndex)
                        Positioned(
                          top: -4 + promotion * 18,
                          left: 0,
                          right: 0,
                          height: cardHeight,
                          child: _BackCard(
                            route: _deck[backIndex],
                            scale: 0.965 + promotion * 0.035,
                            opacity: 0.74 + promotion * 0.26,
                          ),
                        ),
                      Positioned(
                        top: 14,
                        left: 0,
                        right: 0,
                        height: cardHeight,
                        child: widget.showCoach
                            ? RouteSwipeCoachCard(
                                onDismiss: widget.onCoachDismiss ?? _noop,
                              )
                            : GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onHorizontalDragStart: _onPanStart,
                                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                                onHorizontalDragEnd: _onPanEnd,
                                onTap: () => _openDetails(_deck.first),
                                child: Transform.translate(
                                  key: const ValueKey(
                                    'route-swipe-card-translation',
                                  ),
                                  offset: topOffset,
                                  child: Transform.rotate(
                                    angle: angle,
                                    alignment: Alignment.bottomCenter,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        RouteHeroCard(
                                          route: _deck.first,
                                          height: cardHeight,
                                          interactive: false,
                                          variant: RouteCardVariant.deck,
                                          visualProgress: promotion,
                                          tags: const [
                                            'Горы',
                                            'С детьми',
                                            'Пешком',
                                          ],
                                        ),
                                        _SwipeOverlay(progress: progress),
                                      ],
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
          },
        );
      },
    );
  }

  double _progressFor(double dx) => (dx / _swipeThreshold).clamp(-1.0, 1.0);

  double _visualTravelFor(double rawDx, {required bool committing}) {
    final sign = rawDx.sign;
    final distance = rawDx.abs();
    final heldDistance = math.min(distance, _maxHeldDrag);
    final restrained = heldDistance * _dragTravelFactor;
    if (!committing || distance <= _maxHeldDrag) {
      return sign * restrained;
    }
    return sign * (restrained + distance - _maxHeldDrag);
  }
}

void _noop() {}

class _BackCard extends StatelessWidget {
  const _BackCard({
    required this.route,
    required this.scale,
    required this.opacity,
  });

  final RouteSummary route;
  final double scale;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: IgnorePointer(
          child: RepaintBoundary(
            child: RouteHeroCard(
              route: route,
              height: double.infinity,
              interactive: false,
              variant: RouteCardVariant.deck,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeOverlay extends StatelessWidget {
  const _SwipeOverlay({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final opacity = progress.abs().clamp(0.0, 1.0);
    if (opacity < 0.01) {
      return const SizedBox.shrink();
    }
    final favorite = progress > 0;
    final tint = favorite
        ? AppColors.positiveSwipeTint
        : AppColors.negativeSwipeTint;

    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 4.5 * opacity,
            sigmaY: 4.5 * opacity,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.72 * opacity),
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8 * opacity),
              ),
            ),
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (favorite)
                      Container(
                        key: const ValueKey('swipe-action-indicator'),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        child: const AppAssetIcon(
                          AppIconography.heart,
                          color: Colors.white,
                          size: 20,
                        ),
                      )
                    else
                      const SizedBox.square(
                        key: ValueKey('swipe-action-indicator'),
                        dimension: 42,
                        child: Center(
                          child: AppAssetIcon(
                            AppIconography.sendToEnd,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      favorite ? 'В избранное' : 'В конец',
                      style: AppTypography.coach.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
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

/// Animated first card in the deck that teaches the route gestures.
class RouteSwipeCoachCard extends StatefulWidget {
  const RouteSwipeCoachCard({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  State<RouteSwipeCoachCard> createState() => _RouteSwipeCoachCardState();
}

class _RouteSwipeCoachCardState extends State<RouteSwipeCoachCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.emphasized,
      reverseDuration: AppMotion.normal,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_controller.forward());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      key: const ValueKey('route-swipe-coach-card'),
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Обучение жестам маршрутов',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: SizedBox.expand(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final eased = Curves.easeOutCubic.transform(_controller.value);
              final contentScale = reduceMotion ? 1.0 : 0.96 + eased * 0.04;
              final translateY = reduceMotion ? 0.0 : 12 * (1 - eased);

              return BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 10 * eased,
                  sigmaY: 10 * eased,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primaryInk.withValues(alpha: 0.82 * eased),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28 * eased),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Opacity(
                      opacity: eased,
                      child: Transform.translate(
                        offset: Offset(0, translateY),
                        child: Transform.scale(
                          scale: contentScale,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  24,
                                  22,
                                  20,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: math.max(
                                      0,
                                      constraints.maxHeight - 44,
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const _CoachGesture(
                                          kind: _CoachGestureKind.right,
                                          text:
                                              'Свайп вправо добавляет маршрут в «Избранное»',
                                        ),
                                        const SizedBox(height: 8),
                                        const _DashedArrow(
                                          direction: AxisDirection.right,
                                        ),
                                        const SizedBox(height: 10),
                                        const _CoachGesture(
                                          kind: _CoachGestureKind.left,
                                          text:
                                              'Свайп влево отправляет маршрут в конец списка',
                                        ),
                                        const SizedBox(height: 8),
                                        const _DashedArrow(
                                          direction: AxisDirection.left,
                                        ),
                                        const SizedBox(height: 10),
                                        const _CoachGesture(
                                          kind: _CoachGestureKind.tap,
                                          text:
                                              'Кликните на карточку, чтобы узнать подробнее',
                                        ),
                                        const SizedBox(height: 22),
                                        SizedBox(
                                          width: 184,
                                          height: 54,
                                          child: AppGlassSurface(
                                            borderRadius: AppRadii.capsule,
                                            blur: 0,
                                            fillColor: Colors.white.withValues(
                                              alpha: 0.24,
                                            ),
                                            borderColor: Colors.white
                                                .withValues(alpha: 0.46),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadii.capsule,
                                                    ),
                                                onTap: _dismiss,
                                                child: Center(
                                                  child: Text(
                                                    'Хорошо',
                                                    style: AppTypography.button
                                                        .copyWith(
                                                          color: Colors.white,
                                                        ),
                                                  ),
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
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CoachGesture extends StatelessWidget {
  const _CoachGesture({required this.kind, required this.text});

  final _CoachGestureKind kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 56,
          height: 46,
          child: kind == _CoachGestureKind.tap
              ? const Icon(
                  Icons.touch_app_outlined,
                  color: Colors.white,
                  size: 46,
                )
              : CustomPaint(painter: _SwipeGesturePainter(kind)),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.coach.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

enum _CoachGestureKind { right, left, tap }

class _SwipeGesturePainter extends CustomPainter {
  const _SwipeGesturePainter(this.kind);

  final _CoachGestureKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final ink = Paint()
      ..color = AppColors.primaryInk
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final card = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 22,
        height: 40,
      ),
      const Radius.circular(5),
    );
    canvas
      ..drawLine(const Offset(8, 7), const Offset(8, 39), white)
      ..drawLine(Offset(size.width - 8, 7), Offset(size.width - 8, 39), white)
      ..drawRRect(card, fill);

    final pointsRight = kind == _CoachGestureKind.right;
    final centerX = size.width / 2;
    final direction = pointsRight ? 1.0 : -1.0;
    final chevron = Path()
      ..moveTo(centerX - direction * 4, 13)
      ..lineTo(centerX + direction * 4, 23)
      ..lineTo(centerX - direction * 4, 33);
    canvas.drawPath(chevron, ink);
  }

  @override
  bool shouldRepaint(covariant _SwipeGesturePainter oldDelegate) {
    return oldDelegate.kind != kind;
  }
}

class _DashedArrow extends StatelessWidget {
  const _DashedArrow({required this.direction});

  final AxisDirection direction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      height: 24,
      child: CustomPaint(painter: _DashedArrowPainter(direction)),
    );
  }
}

class _DashedArrowPainter extends CustomPainter {
  const _DashedArrowPainter(this.direction);

  final AxisDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 8.0;
    const dashGap = 5.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final y = size.height / 2;
    final pointsRight = direction == AxisDirection.right;
    final lineStart = pointsRight ? 0.0 : 12.0;
    final lineEnd = pointsRight ? size.width - 12 : size.width;

    for (var x = lineStart; x < lineEnd; x += dashWidth + dashGap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dashWidth, lineEnd), y),
        paint,
      );
    }

    final tipX = pointsRight ? size.width - 1 : 1.0;
    final baseX = pointsRight ? size.width - 12 : 12.0;
    canvas
      ..drawLine(Offset(baseX, y - 7), Offset(tipX, y), paint)
      ..drawLine(Offset(baseX, y + 7), Offset(tipX, y), paint);
  }

  @override
  bool shouldRepaint(covariant _DashedArrowPainter oldDelegate) {
    return oldDelegate.direction != direction;
  }
}
