import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/places/presentation/places_catalog_screen.dart';
import 'package:tourism_mobile/features/profile/presentation/profile_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/routes_catalog_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_media_header.dart';
import 'package:tourism_mobile/features/settings/application/settings_providers.dart';
import 'package:tourism_mobile/routing/shell/tab_scroll_to_top.dart';

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
const _appNavDestinationCount = 5;

/// Compact droplet parks on the destination **slot center**, not the bar edge.
///
/// Edge parking (`width ± diameter/2`) is a few px off the last/first tab
/// centers, so Profile→Settings (and reverse expand) looked like the active
/// pill drifting sideways. Slot-center parking keeps translation of the
/// compact destination at 0 for the whole collapse/expand.
@visibleForTesting
double floatingNavCompactCenterX({
  required double width,
  required int compactDestinationIndex,
  int destinationCount = _appNavDestinationCount,
}) {
  assert(destinationCount > 0);
  assert(
    compactDestinationIndex >= 0 && compactDestinationIndex < destinationCount,
  );
  final slotWidth = width / destinationCount;
  return (compactDestinationIndex + 0.5) * slotWidth;
}

final _appFloatingNavKey = GlobalKey<_AppFloatingNavBarState>(
  debugLabel: 'app-floating-navigation',
);

class AppShellScreen extends ConsumerWidget {
  const AppShellScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  int? _detailNavigationIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final segments = Uri.parse(location).pathSegments;
    if (segments.length >= 2 && segments.first == 'routes') {
      // `/routes/:id` and nested `/routes/:id/place/:placeId` keep Routes chrome.
      return 0;
    }
    if (segments.length == 2 && segments.first == 'places') {
      return 3;
    }
    // `/profile/settings` and every nested settings screen.
    if (segments.length >= 2 &&
        segments.first == 'profile' &&
        segments[1] == 'settings') {
      return 4;
    }
    return null;
  }

  /// Guest/demo profile: `/profile/users/:userId` for another traveler.
  bool _isGuestProfilePath(BuildContext context, WidgetRef ref) {
    final segments = GoRouterState.of(context).uri.pathSegments;
    if (segments.length < 3 ||
        segments[0] != 'profile' ||
        segments[1] != 'users') {
      return false;
    }
    final viewedId = segments[2];
    final selfId = ref.watch(sessionProvider).userId;
    return viewedId.isNotEmpty && viewedId != selfId;
  }

  void _onDestinationSelected(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) {
    final onCurrentBranch = index == navigationShell.currentIndex;
    final path = GoRouterState.of(context).uri.path;
    final scrolledDown = ref.read(tabScrolledDownProvider(index));
    if (onCurrentBranch &&
        (scrolledDown || _isBranchRootPath(path, index))) {
      unawaited(HapticFeedback.selectionClick());
      ref.read(tabScrollToTopProvider(index).notifier).state++;
      return;
    }
    navigationShell.goBranch(
      index,
      initialLocation: onCurrentBranch,
    );
  }

  static bool _isBranchRootPath(String path, int index) {
    switch (index) {
      case 0:
        return path == HomeScreen.routePath || path == '/';
      case 1:
        return path == RoutesCatalogScreen.routePath;
      case 2:
        return path == '/favorites';
      case 3:
        return path == PlacesCatalogScreen.routePath;
      case 4:
        return path == ProfileScreen.routePath;
      default:
        return false;
    }
  }

  void _startRoute(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Прохождение маршрута появится позже')),
      );
  }

  void _continueTravelPlus(BuildContext context, WidgetRef ref) {
    ref
        .read(settingsPreferencesProvider.notifier)
        .activateTravelPlus(yearly: true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Подписка активирована (мок)')),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final path = GoRouterState.of(context).uri.path;
    final detailNavigationIndex = _detailNavigationIndex(context);
    final guestProfile = _isGuestProfilePath(context, ref);
    final showDetailsChrome = detailNavigationIndex != null;
    final currentIndex = navigationShell.currentIndex;
    final scrolledDown = ref.watch(tabScrolledDownProvider(currentIndex));
    final showRouteAction = detailNavigationIndex == 0;
    // CTA only on Travel+ paywall — other settings keep compact nav alone.
    final showTravelPlusAction =
        detailNavigationIndex == 4 && path.contains('/travel-plus');
    final detailActionLabel = showTravelPlusAction
        ? 'Продолжить'
        : 'Пройти маршрут';
    final VoidCallback? detailAction = showRouteAction
        ? () => _startRoute(context)
        : showTravelPlusAction
        ? () => _continueTravelPlus(context, ref)
        : null;

    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          navigationShell,
          if (showDetailsChrome)
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
              currentIndex: currentIndex,
              onTap: (index) => _onDestinationSelected(context, ref, index),
              detailMode: showDetailsChrome,
              // Guest profile keeps the full nav; Home slot becomes history back.
              historyBackMode: guestProfile,
              scrollToTopMode: scrolledDown && !guestProfile,
              compactDestinationIndex:
                  detailNavigationIndex ?? currentIndex,
              onHistoryBack: () {
                unawaited(HapticFeedback.selectionClick());
                if (context.canPop()) {
                  context.pop();
                }
              },
              onStartRoute: detailAction,
              startRouteLabel: detailActionLabel,
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
    this.historyBackMode = false,
    this.scrollToTopMode = false,
    this.compactDestinationIndex = 0,
    this.onHistoryBack,
    this.onStartRoute,
    this.startRouteLabel = 'Пройти маршрут',
    super.key,
  }) : assert(
         compactDestinationIndex >= 0 &&
             compactDestinationIndex < _appNavDestinationCount,
       );

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool detailMode;
  final bool historyBackMode;
  final bool scrollToTopMode;
  final int compactDestinationIndex;
  final VoidCallback? onHistoryBack;
  final VoidCallback? onStartRoute;
  final String startRouteLabel;

  /// Only detail/settings chrome collapses the bar. Guest back keeps full nav.
  bool get compactChrome => detailMode;

  @override
  State<AppFloatingNavBar> createState() => _AppFloatingNavBarState();
}

class _AppFloatingNavBarState extends State<AppFloatingNavBar>
    with TickerProviderStateMixin {
  static const _height = 58.0;
  static const _detailHeight = 126.0;
  static const _activeDiameter = 58.0;
  static const _segmentGap = 10.0;
  static const _autoCollapseDelay = Duration(seconds: 5);

  late final AnimationController _positionController;
  late final AnimationController _detailPresenceController;
  late final AnimationController _detailExpansionController;
  late double _position;
  late double _fromPosition;
  late int _targetIndex;
  Timer? _autoCollapseTimer;

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
      value: widget.compactChrome ? 1 : 0,
    )..addListener(_rebuild);
    _detailExpansionController = AnimationController(
      vsync: this,
      duration: AppMotion.detailMorph,
    )..addListener(_rebuild);
    if (widget.compactChrome) {
      _position = widget.compactDestinationIndex.toDouble();
      _fromPosition = _position;
      _targetIndex = widget.compactDestinationIndex;
    }
  }

  @override
  void didUpdateWidget(covariant AppFloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.compactChrome != oldWidget.compactChrome) {
      if (widget.compactChrome) {
        _cancelAutoCollapse();
        _detailExpansionController.value = 0;
        _animateTo(widget.compactDestinationIndex);
        _animateDetailPresence(1);
      } else {
        _cancelAutoCollapse();
        _animateTo(widget.currentIndex);
        _animateDetailPresence(0);
        _detailExpansionController.value = 0;
      }
    } else if (widget.compactChrome &&
        widget.compactDestinationIndex != oldWidget.compactDestinationIndex) {
      _cancelAutoCollapse();
      _detailExpansionController.value = 0;
      _animateTo(widget.compactDestinationIndex);
    } else if (!widget.compactChrome && widget.currentIndex != _targetIndex) {
      _animateTo(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _cancelAutoCollapse();
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

  void _cancelAutoCollapse() {
    _autoCollapseTimer?.cancel();
    _autoCollapseTimer = null;
  }

  void _scheduleAutoCollapse() {
    _cancelAutoCollapse();
    if (!widget.detailMode || _detailExpansionController.value < 0.99) {
      return;
    }
    _autoCollapseTimer = Timer(_autoCollapseDelay, _collapseDetailNavigation);
  }

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
    _cancelAutoCollapse();
    _detailExpansionController.duration =
        MediaQuery.disableAnimationsOf(context)
        ? AppMotion.reduced
        : AppMotion.detailMorph;
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      _detailExpansionController.forward().then((_) {
        if (!mounted || !widget.detailMode) {
          return;
        }
        setState(() {});
        _scheduleAutoCollapse();
      }),
    );
  }

  void _collapseDetailNavigation() {
    if (!mounted || !widget.detailMode) {
      return;
    }
    if (_detailExpansionController.value <= 0) {
      return;
    }
    _cancelAutoCollapse();
    _detailExpansionController.duration =
        MediaQuery.disableAnimationsOf(context)
        ? AppMotion.reduced
        : AppMotion.detailMorph;
    unawaited(_detailExpansionController.reverse());
  }

  void _handleTap(int index) {
    // Guest profile: Home slot is history-back (same as edge swipe).
    if (widget.historyBackMode && index == 0) {
      widget.onHistoryBack?.call();
      return;
    }
    if (widget.detailMode &&
        _detailExpansionController.value < 1 &&
        index == widget.compactDestinationIndex) {
      _expandDetailNavigation();
      return;
    }
    // Any tap on the expanded menu postpones auto-collapse.
    if (widget.detailMode && _detailExpansionController.value > 0.5) {
      _scheduleAutoCollapse();
    }
    if (index != widget.currentIndex) {
      unawaited(HapticFeedback.selectionClick());
      _animateTo(index);
    }
    widget.onTap(index);
  }

  void _handleCompactOverlayTap() {
    _expandDetailNavigation();
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
        widget.compactChrome ||
        _detailPresenceController.isAnimating ||
        presence > 0.001;
    final hasDetailAction =
        widget.detailMode && widget.onStartRoute != null;
    final totalHeight = showDetailLayout && hasDetailAction
        ? _detailHeight
        : _height;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        key: const ValueKey('app-shell-bottom-bar'),
        height: totalHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compactOnRight = widget.compactDestinationIndex >= 3;
            // Expand: mostly rise first, then widen — soft overlap, no expo snap.
            final expandT = (1 - compactProgress).clamp(0.0, 1.0);
            final riseT = Curves.easeInOutCubic.transform(
              (expandT / 0.58).clamp(0.0, 1.0),
            );
            final widenT = expandT <= 0.28
                ? 0.0
                : Curves.easeInOutCubic.transform(
                    ((expandT - 0.28) / 0.72).clamp(0.0, 1.0),
                  );
            final ctaInset =
                (_activeDiameter + _segmentGap) * (1 - widenT);
            final ctaTop = (_detailHeight - _height) * (1 - riseT);
            // ~13% narrower than the track next to the compact droplet.
            final ctaTrack = math.max(0.0, width - ctaInset);
            final ctaSidePad = ctaTrack * 0.065;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (widget.detailMode && widget.onStartRoute != null)
                  Positioned(
                    key: const ValueKey('route-start-button-position'),
                    left: (compactOnRight ? 0.0 : ctaInset) + ctaSidePad,
                    right: (compactOnRight ? ctaInset : 0.0) + ctaSidePad,
                    top: ctaTop,
                    height: _height,
                    child: RouteStartButton(
                      visibility: presence,
                      morphProgress: 1 - widenT,
                      onPressed: widget.onStartRoute!,
                      label: widget.startRouteLabel,
                      compactAlignedRight: compactOnRight,
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
    final compactCenterX = floatingNavCompactCenterX(
      width: width,
      compactDestinationIndex: widget.compactDestinationIndex,
    );
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
    final compactLeft = compactCenterX - _activeDiameter / 2;

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
                        visibility: index == widget.compactDestinationIndex
                            ? 1
                            : ((revealProgress -
                                          (index -
                                                      widget
                                                          .compactDestinationIndex)
                                                  .abs() *
                                              0.04) /
                                      0.78)
                                  .clamp(0, 1),
                        translationX:
                            (compactCenterX - (index + 0.5) * slotWidth) *
                            compactProgress,
                        showHistoryBack:
                            widget.historyBackMode && index == 0,
                        showScrollToTop:
                            widget.scrollToTopMode &&
                            index == widget.currentIndex &&
                            !widget.compactChrome &&
                            !(widget.historyBackMode && index == 0),
                        onTap: _handleTap,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (compactProgress > 0.995)
            Positioned(
              left: compactLeft,
              top: 0,
              width: _activeDiameter,
              height: _height,
              child: Semantics(
                label:
                    'Развернуть навигацию, выбран раздел '
                    '${_appNavDestinations[widget.compactDestinationIndex].label}',
                button: true,
                selected: true,
                child: Tooltip(
                  message: 'Развернуть навигацию',
                  child: GestureDetector(
                    key: const ValueKey('expand-detail-navigation'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _handleCompactOverlayTap,
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
    this.showHistoryBack = false,
    this.showScrollToTop = false,
    required this.onTap,
  });

  final _NavDestination destination;
  final int index;
  final double activeWeight;
  final double visibility;
  final double translationX;
  final bool showHistoryBack;
  final bool showScrollToTop;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = activeWeight > 0.99 && !showHistoryBack;
    final inactiveColor = AppColors.inactiveNavigationIcon.withValues(
      alpha: 0.84 * visibility,
    );
    final label = showHistoryBack
        ? 'Назад'
        : showScrollToTop
        ? 'Наверх'
        : destination.label;

    return ExcludeSemantics(
      excluding: visibility < 0.99,
      child: IgnorePointer(
        ignoring: visibility < 0.99,
        child: Transform.translate(
          offset: Offset(translationX, 0),
          child: Semantics(
            label: label,
            button: true,
            selected: selected,
            sortKey: OrdinalSortKey(index.toDouble()),
            child: Tooltip(
              message: label,
              child: InkResponse(
                onTap: () => onTap(index),
                radius: 30,
                containedInkWell: true,
                highlightShape: BoxShape.circle,
                child: Center(
                  child: showHistoryBack
                      ? Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: AppColors.inactiveNavigationIcon.withValues(
                            alpha: 0.92 * visibility,
                          ),
                        )
                      : showScrollToTop
                      ? Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 28,
                          color: Colors.white.withValues(
                            alpha: activeWeight * visibility,
                          ),
                        )
                      : Stack(
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
