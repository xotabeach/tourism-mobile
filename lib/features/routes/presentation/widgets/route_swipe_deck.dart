import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/core/performance/app_perf.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/routing/app_router.dart';

enum RouteSwipeAction { favorite, skip }

enum _DeckSettleKind { swipeCommit, coachDismiss }

class _DeckGeometry {
  const _DeckGeometry({
    required this.top,
    required this.left,
    required this.right,
    required this.scale,
    required this.opacity,
    required this.angle,
  });

  final double top;
  final double left;
  final double right;
  final double scale;
  final double opacity;
  final double angle;

  static _DeckGeometry lerp(
    _DeckGeometry begin,
    _DeckGeometry end,
    double progress,
  ) {
    return _DeckGeometry(
      top: lerpDouble(begin.top, end.top, progress)!,
      left: lerpDouble(begin.left, end.left, progress)!,
      right: lerpDouble(begin.right, end.right, progress)!,
      scale: lerpDouble(begin.scale, end.scale, progress)!,
      opacity: lerpDouble(begin.opacity, end.opacity, progress)!,
      angle: lerpDouble(begin.angle, end.angle, progress)!,
    );
  }
}

/// Responsive swipe stack with deterministic progress rendering for goldens.
class RouteSwipeDeck extends StatefulWidget {
  const RouteSwipeDeck({
    required this.routes,
    required this.onSwipe,
    this.onOpenAllRoutes,
    this.showCoach = false,
    this.onCoachDismiss,
    this.debugProgress,
    super.key,
  });

  final List<RouteSummary> routes;
  final void Function(RouteSummary route, RouteSwipeAction action) onSwipe;

  /// "Открыть список маршрутов" on the deck-exhausted panel. Optional so
  /// goldens/tests can render the deck without wiring navigation.
  final VoidCallback? onOpenAllRoutes;
  final bool showCoach;
  final VoidCallback? onCoachDismiss;

  /// Test-only visual state. Values are clamped to -1...1.
  final double? debugProgress;

  @override
  State<RouteSwipeDeck> createState() => _RouteSwipeDeckState();
}

class _RouteSwipeDeckState extends State<RouteSwipeDeck>
    with TickerProviderStateMixin {
  static const double _swipeThreshold = 118;
  static const double _dragTravelFactor = 0.34;
  static const double _maxHeldDrag = _swipeThreshold * 1.1;
  static const double _maxAngle = math.pi / 20;
  static const _frontGeometry = _DeckGeometry(
    top: 17,
    left: 0,
    right: 0,
    scale: 1,
    opacity: 1,
    angle: 0,
  );
  static const _restingBackGeometry = _DeckGeometry(
    top: -6,
    left: 6,
    right: -6,
    scale: 0.965,
    opacity: 0.78,
    angle: 0.03,
  );
  static const _promotedBackGeometry = _DeckGeometry(
    top: 10,
    left: 6,
    right: -6,
    scale: 1,
    opacity: 1,
    angle: 0,
  );
  static const _restingFarGeometry = _DeckGeometry(
    top: -8,
    left: -10,
    right: 10,
    scale: 0.94,
    opacity: 0.5,
    angle: -0.042,
  );
  static const _promotedFarGeometry = _DeckGeometry(
    top: -7,
    left: -4,
    right: 4,
    scale: 0.955,
    opacity: 0.68,
    angle: -0.012,
  );
  static const _enteringFarGeometry = _DeckGeometry(
    top: -12,
    left: -12,
    right: 12,
    scale: 0.91,
    opacity: 0,
    angle: -0.052,
  );

  late List<RouteSummary> _deck;
  late final AnimationController _motionController;
  late final AnimationController _settleController;
  late final Listenable _deckAnimation;
  Animation<Offset>? _offsetAnimation;
  _DeckSettleKind? _settleKind;
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
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: 1,
    );
    _deckAnimation = Listenable.merge([_motionController, _settleController]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheDeckImages();
  }

  @override
  void didUpdateWidget(covariant RouteSwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showCoach && !widget.showCoach) {
      _animateCoachDismiss();
    }
    if (_sameRouteOrder(oldWidget.routes, widget.routes)) {
      return;
    }
    if (_sameRouteSet(oldWidget.routes, widget.routes)) {
      _deck = _reconcileDeck(widget.routes);
      _precacheDeckImages();
      return;
    }
    if (!listEquals(oldWidget.routes, widget.routes)) {
      _deck = _reconcileDeck(widget.routes);
      _resetMotion();
      _precacheDeckImages();
    }
  }

  bool _sameRouteOrder(List<RouteSummary> a, List<RouteSummary> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) {
        return false;
      }
    }
    return true;
  }

  bool _sameRouteSet(List<RouteSummary> a, List<RouteSummary> b) {
    if (a.length != b.length) {
      return false;
    }
    final aIds = a.map((route) => route.id).toSet();
    final bIds = b.map((route) => route.id).toSet();
    return aIds.length == bIds.length && aIds.containsAll(bIds);
  }

  List<RouteSummary> _reconcileDeck(List<RouteSummary> incomingRoutes) {
    if (_deck.isEmpty) {
      return List<RouteSummary>.from(incomingRoutes);
    }
    final routeById = {for (final route in incomingRoutes) route.id: route};
    final next = <RouteSummary>[];
    for (final route in _deck) {
      final fresh = routeById.remove(route.id);
      if (fresh != null) {
        next.add(fresh);
      }
    }
    next.addAll(routeById.values);
    return next;
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
    _settleController.dispose();
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
    _settleKind = null;
    _dragOffset = Offset.zero;
    _pendingAction = null;
    _dragging = false;
    _settleController.value = 1;
  }

  void _animateCoachDismiss() {
    if (_motionController.isAnimating || _deck.isEmpty) {
      return;
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _settleKind = _DeckSettleKind.coachDismiss;
    _settleController.duration = reduceMotion
        ? AppMotion.reduced
        : AppPerf.motion(const Duration(milliseconds: 340));
    if (reduceMotion) {
      setState(() => _settleController.value = 1);
      return;
    }
    setState(() => _settleController.value = 0);
    unawaited(
      _settleController.forward().whenComplete(() {
        if (mounted && _settleKind == _DeckSettleKind.coachDismiss) {
          setState(() => _settleKind = null);
        }
      }),
    );
  }

  void _onPanStart(DragStartDetails _) {
    if (_motionController.isAnimating ||
        _settleController.isAnimating ||
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
        : AppPerf.motion(const Duration(milliseconds: 340));
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
    unawaited(AppHaptics.mediumImpact());
    _motionController.duration = reduceMotion
        ? AppMotion.reduced
        : AppPerf.motion(AppMotion.emphasized);
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
    widget.onSwipe(route, action);
    // Skipped cards are dropped, not requeued: a deck that recycles "not
    // interested" swipes back to the end never actually ends, and re-showing
    // a card the user just rejected isn't a recommendation, it's a loop.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    setState(() {
      _motionController.reset();
      _offsetAnimation = null;
      _settleKind = _DeckSettleKind.swipeCommit;
      _dragOffset = Offset.zero;
      _pendingAction = null;
      _dragging = false;
      _settleController.value = reduceMotion ? 1 : 0;
    });
    if (!reduceMotion) {
      unawaited(_settleController.forward());
    }
  }

  void _openDetails(RouteSummary route) {
    if (_motionController.isAnimating ||
        _settleController.isAnimating ||
        widget.showCoach ||
        widget.debugProgress != null) {
      return;
    }
    unawaited(
      context.pushNamed(
        AppRouteNames.routeDetails,
        pathParameters: {'id': route.id},
        extra: route,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_deck.isEmpty) {
      return _DeckExhaustedView(onOpenAllRoutes: widget.onOpenAllRoutes);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth - AppSpacing.page * 2;
        final baseHeight = cardWidth * 1.5;
        final maxUsableHeight = math.max(320.0, constraints.maxHeight - 104);
        // Preserve the original 2:3 composition on compact screens, then use
        // part of the extra vertical room on tall phones. Capping at 1.72×
        // keeps portraits and controls from looking unnaturally stretched.
        final adaptiveGrowth =
            math.max(0.0, maxUsableHeight - baseHeight) * .62;
        final cardHeight = math.min(
          maxUsableHeight,
          math.min(cardWidth * 1.72, baseHeight + adaptiveGrowth),
        );

        return AnimatedBuilder(
          animation: _deckAnimation,
          builder: (context, _) {
            final debugProgress = widget.debugProgress?.clamp(-1.0, 1.0);
            final rawOffset = debugProgress != null
                ? Offset(debugProgress * _swipeThreshold, 0)
                : (_offsetAnimation?.value ?? _dragOffset);
            final progress = debugProgress ?? _progressFor(rawOffset.dx);
            final dragPromotion = widget.showCoach
                ? 0.0
                : _smoothPromotion(progress.abs());
            final settling = _settleController.value < 1;
            final settleProgress = settling
                ? AppMotion.emphasizedCurve.transform(_settleController.value)
                : 1.0;
            final settleKind = _settleKind;
            final frontGeometry = settling
                ? _DeckGeometry.lerp(
                    settleKind == _DeckSettleKind.coachDismiss
                        ? _restingBackGeometry
                        : _promotedBackGeometry,
                    _frontGeometry,
                    settleProgress,
                  )
                : _frontGeometry;
            final backGeometry = settling
                ? _DeckGeometry.lerp(
                    settleKind == _DeckSettleKind.coachDismiss
                        ? _restingFarGeometry
                        : _promotedFarGeometry,
                    _restingBackGeometry,
                    settleProgress,
                  )
                : _DeckGeometry.lerp(
                    _restingBackGeometry,
                    _promotedBackGeometry,
                    dragPromotion,
                  );
            final farGeometry = settling
                ? _DeckGeometry.lerp(
                    _enteringFarGeometry,
                    _restingFarGeometry,
                    settleProgress,
                  )
                : _DeckGeometry.lerp(
                    _restingFarGeometry,
                    _promotedFarGeometry,
                    dragPromotion,
                  );
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
                  height: cardHeight + 24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (_deck.length > farBackIndex)
                        Positioned(
                          key: ValueKey(
                            'route-layer-${_deck[farBackIndex].id}',
                          ),
                          top: farGeometry.top,
                          left: farGeometry.left,
                          right: farGeometry.right,
                          height: cardHeight,
                          child: _BackCard(
                            route: _deck[farBackIndex],
                            scale: farGeometry.scale,
                            opacity: farGeometry.opacity,
                            angle: farGeometry.angle,
                          ),
                        ),
                      if (_deck.length > backIndex)
                        Positioned(
                          key: ValueKey('route-layer-${_deck[backIndex].id}'),
                          top: backGeometry.top,
                          left: backGeometry.left,
                          right: backGeometry.right,
                          height: cardHeight,
                          child: _BackCard(
                            route: _deck[backIndex],
                            scale: backGeometry.scale,
                            opacity: backGeometry.opacity,
                            angle: backGeometry.angle,
                          ),
                        ),
                      Positioned(
                        key: widget.showCoach
                            ? const ValueKey('route-coach-layer')
                            : ValueKey('route-layer-${_deck.first.id}'),
                        top: frontGeometry.top,
                        left: frontGeometry.left,
                        right: frontGeometry.right,
                        height: cardHeight,
                        child: Transform.scale(
                          scale: frontGeometry.scale,
                          child: widget.showCoach
                              ? DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.card,
                                    ),
                                    boxShadow: AppShadows.deck,
                                  ),
                                  child: RouteSwipeCoachCard(
                                    onDismiss: widget.onCoachDismiss ?? _noop,
                                  ),
                                )
                              : GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onHorizontalDragStart: _onPanStart,
                                  onHorizontalDragUpdate:
                                      _onHorizontalDragUpdate,
                                  onHorizontalDragEnd: _onPanEnd,
                                  onTap: () => _openDetails(_deck.first),
                                  child: Transform.translate(
                                    key: const ValueKey(
                                      'route-swipe-card-translation',
                                    ),
                                    offset: topOffset,
                                    child: Transform.rotate(
                                      angle: frontGeometry.angle + angle,
                                      alignment: Alignment.bottomCenter,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.card,
                                          ),
                                          boxShadow: AppShadows.deck,
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            RouteHeroCard(
                                              route: _deck.first,
                                              height: cardHeight,
                                              interactive: false,
                                              variant: RouteCardVariant.deck,
                                              visualProgress: progress.abs(),
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

  double _smoothPromotion(double progress) {
    final t = progress.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

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

/// Shown once every candidate for the day has been swiped through.
///
/// The deck is finite by design (see [RouteSwipeDeck._finishSwipe]): skipped
/// cards are dropped, not requeued, and favorited routes never appear here
/// (filtered before the deck is built). This is the natural rest state, not
/// an error — no retry, just a way out to the plain list.
class _DeckExhaustedView extends StatelessWidget {
  const _DeckExhaustedView({this.onOpenAllRoutes});

  final VoidCallback? onOpenAllRoutes;

  @override
  Widget build(BuildContext context) {
    const message = 'Вы разобрали все маршруты на сегодня';
    return Semantics(
      liveRegion: true,
      label: message,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.task_alt_rounded, size: 32),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Новые подборки появляются каждый день',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryInk,
                ),
              ),
              if (onOpenAllRoutes != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: onOpenAllRoutes,
                  icon: const Icon(Icons.list_rounded),
                  label: const Text('Открыть список маршрутов'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BackCard extends StatelessWidget {
  const _BackCard({
    required this.route,
    required this.scale,
    required this.opacity,
    required this.angle,
  });

  final RouteSummary route;
  final double scale;
  final double opacity;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      alignment: Alignment.bottomCenter,
      child: Transform.scale(
        scale: scale,
        child: AppFilteredOpacity(
          opacity: opacity,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  boxShadow: AppShadows.deck,
                ),
                child: RouteHeroCard(
                  route: route,
                  height: double.infinity,
                  interactive: false,
                  variant: RouteCardVariant.deck,
                ),
              ),
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

    final blurSigma = AppPerf.glassBlur(4.5 * opacity);
    final overlay = DecoratedBox(
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
              SizedBox.square(
                key: const ValueKey('swipe-action-indicator'),
                dimension: 52,
                child: AppGlassSurface(
                  borderRadius: AppRadii.circle,
                  blur: 14,
                  fillColor: Colors.white.withValues(alpha: 0.20),
                  borderColor: Colors.white.withValues(alpha: 0.72),
                  contentColor: Colors.white,
                  boxShadow: const [],
                  child: Center(
                    child: AppAssetIcon(
                      favorite
                          ? AppIconography.heart
                          : AppIconography.sendToEnd,
                      color: Colors.white,
                      size: 24,
                    ),
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
    );

    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: blurSigma <= 0
            ? overlay
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: overlay,
              ),
      ),
    );
  }
}

/// Animated scrim over the first deck card that teaches the route gestures.
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
    final useCupertinoGlass = Theme.of(context).platform == TargetPlatform.iOS;

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

              final coachBlur = AppPerf.glassBlur(5.5 * eased);
              final coachSurface = DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primaryInk.withValues(alpha: 0.72 * eased),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22 * eased),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Transform.translate(
                    offset: Offset(0, translateY),
                    child: Transform.scale(
                      scale: contentScale,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
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
                                    Opacity(
                                      opacity: eased,
                                      child: const Column(
                                        children: [
                                          _CoachGesture(
                                            kind: _CoachGestureKind.right,
                                            text:
                                                'Свайп вправо добавляет маршрут в «Избранное»',
                                          ),
                                          SizedBox(height: 8),
                                          _DashedArrow(
                                            direction: AxisDirection.right,
                                          ),
                                          SizedBox(height: 10),
                                          _CoachGesture(
                                            kind: _CoachGestureKind.left,
                                            text:
                                                'Свайп влево отправляет маршрут в конец списка',
                                          ),
                                          SizedBox(height: 8),
                                          _DashedArrow(
                                            direction: AxisDirection.left,
                                          ),
                                          SizedBox(height: 10),
                                          _CoachGesture(
                                            kind: _CoachGestureKind.tap,
                                            text:
                                                'Кликните на карточку, чтобы узнать подробнее',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    SizedBox(
                                      width: 244,
                                      height: 62,
                                      child: AppGlassSurface(
                                        key: const ValueKey(
                                          'route-swipe-coach-cta-glass',
                                        ),
                                        borderRadius: AppRadii.capsule,
                                        blur: useCupertinoGlass
                                            ? 18 * eased
                                            : 0,
                                        fillColor: Colors.white.withValues(
                                          alpha:
                                              (useCupertinoGlass
                                                  ? 0.38
                                                  : 0.24) *
                                              eased,
                                        ),
                                        borderColor: Colors.white.withValues(
                                          alpha:
                                              (useCupertinoGlass
                                                  ? 0.88
                                                  : 0.46) *
                                              eased,
                                        ),
                                        contentColor: Colors.white,
                                        borderWidth: useCupertinoGlass
                                            ? 1.2
                                            : 1,
                                        boxShadow: useCupertinoGlass
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0x30000000)
                                                      .withValues(
                                                        alpha: 0.22 * eased,
                                                      ),
                                                  blurRadius: 18,
                                                  offset: const Offset(0, 8),
                                                ),
                                                BoxShadow(
                                                  color: const Color(0x66FFFFFF)
                                                      .withValues(
                                                        alpha: 0.45 * eased,
                                                      ),
                                                  blurRadius: 14,
                                                  offset: const Offset(0, -3),
                                                ),
                                              ]
                                            : AppShadows.glass,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              AppRadii.capsule,
                                            ),
                                            onTap: _dismiss,
                                            child: Center(
                                              child: Opacity(
                                                opacity: eased,
                                                child: Text(
                                                  'Хорошо',
                                                  style: AppTypography.button
                                                      .copyWith(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
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
              );

              if (coachBlur <= 0) {
                return coachSurface;
              }
              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: coachBlur, sigmaY: coachBlur),
                child: coachSurface,
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
          width: 64,
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _SwipeGesturePainter(kind)),
              ),
              if (kind == _CoachGestureKind.tap)
                // SVG optical center sits a bit high; nudge down inside the card.
                Transform.translate(
                  offset: const Offset(0, 2),
                  child: const AppAssetIcon(
                    AppIconography.click,
                    size: 34,
                    color: AppColors.primaryInk,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 216,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.coach.copyWith(color: Colors.white),
          ),
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
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final ink = Paint()
      ..color = AppColors.primaryInk
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final card = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 28,
        height: 46,
      ),
      const Radius.circular(7),
    );
    canvas
      ..drawLine(const Offset(8, 10), Offset(8, size.height - 10), white)
      ..drawLine(
        Offset(size.width - 8, 10),
        Offset(size.width - 8, size.height - 10),
        white,
      )
      ..drawRRect(card, fill);

    if (kind == _CoachGestureKind.tap) {
      return;
    }

    // Left chevron sits well at -1; right is a milder +4 (was too far right).
    final pointsRight = kind == _CoachGestureKind.right;
    final direction = pointsRight ? 1.0 : -1.0;
    final centerX = size.width / 2 + (pointsRight ? 1.0 : -1.0);
    final centerY = size.height / 2;
    final chevron = Path()
      ..moveTo(centerX - direction * 5, centerY - 9)
      ..lineTo(centerX + direction * 4, centerY)
      ..lineTo(centerX - direction * 5, centerY + 9);
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
      width: 260,
      height: 18,
      child: CustomPaint(painter: _DashedArrowPainter(direction)),
    );
  }
}

class _DashedArrowPainter extends CustomPainter {
  const _DashedArrowPainter(this.direction);

  final AxisDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 6.0;
    const dashGap = 4.0;
    const tipPad = 8.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = 1.85
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final y = size.height / 2;
    final pointsRight = direction == AxisDirection.right;
    final lineStart = pointsRight ? 0.0 : tipPad;
    final lineEnd = pointsRight ? size.width - tipPad : size.width;

    for (var x = lineStart; x < lineEnd; x += dashWidth + dashGap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dashWidth, lineEnd), y),
        paint,
      );
    }

    final tipX = pointsRight ? size.width - 1 : 1.0;
    final baseX = pointsRight ? size.width - tipPad : tipPad;
    canvas
      ..drawLine(Offset(baseX, y - 5.5), Offset(tipX, y), paint)
      ..drawLine(Offset(baseX, y + 5.5), Offset(tipX, y), paint);
  }

  @override
  bool shouldRepaint(covariant _DashedArrowPainter oldDelegate) {
    return oldDelegate.direction != direction;
  }
}
