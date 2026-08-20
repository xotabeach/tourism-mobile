import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/cache/app_data_refresh.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/core/performance/app_perf.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/my_routes/presentation/my_routes_screen.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/profile/presentation/profile_screen.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_ai_mode_provider.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_screen.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_publish_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/routes_catalog_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_media_header.dart';
import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';
import 'package:tourism_mobile/features/settings/presentation/inbox_foreground_host.dart';
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
    label: 'Создать',
    icon: AppIconography.build,
    selectedIcon: AppIconography.build,
  ),
  _NavDestination(
    label: 'Избранное',
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
const _composeNavIndex = 2;

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

class AppShellScreen extends ConsumerStatefulWidget {
  const AppShellScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen>
    with WidgetsBindingObserver {
  late int _lastTabIndex;

  @override
  void initState() {
    super.initState();
    _lastTabIndex = widget.navigationShell.currentIndex;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }
    // Keep current UI; refresh only the active tab (+ inbox) in the background.
    softRefreshAppData(
      ref,
      scope: appDataRefreshScopeForTab(widget.navigationShell.currentIndex),
    );
    if (ref.read(sessionProvider).isAuthenticated) {
      unawaited(ref.read(notificationsInboxProvider.notifier).softRefresh());
    }
  }

  void _softRefreshCurrentTab(int index) {
    // Compose tab has no catalog payload; skip noisy all-scope refresh.
    if (index == _composeNavIndex) {
      return;
    }
    softRefreshAppData(ref, scope: appDataRefreshScopeForTab(index));
  }

  int? _detailNavigationIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final segments = Uri.parse(location).pathSegments;
    if (location == RoutePublishScreen.routePath ||
        (segments.isNotEmpty &&
            segments.first == RouteMatchScreen.routePath.substring(1))) {
      return _composeNavIndex;
    }
    if (segments.length >= 2 && segments.first == 'routes') {
      // Route details keep the compact droplet on Home (original chrome).
      return 0;
    }
    // Places live under home now; place details keep home chrome compact.
    if (segments.length >= 2 && segments.first == 'places') {
      return 0;
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

  void _onDestinationSelected(BuildContext context, int index) {
    // Center "+" opens compose actions; it is not a tab destination by itself.
    if (index == _composeNavIndex) {
      return;
    }
    // Detail chrome (route/place/settings): hard-go to the branch root so a
    // second Home tap cannot leave a stuck nested stack entry.
    if (_detailNavigationIndex(context) != null) {
      unawaited(AppHaptics.selectionClick());
      context.go(_branchRootPath(index));
      return;
    }
    final onCurrentBranch = index == widget.navigationShell.currentIndex;
    final path = GoRouterState.of(context).uri.path;
    final scrolledDown = ref.read(tabScrolledDownProvider(index));
    if (onCurrentBranch && (scrolledDown || _isBranchRootPath(path, index))) {
      unawaited(AppHaptics.selectionClick());
      ref.read(tabScrollToTopProvider(index).notifier).state++;
      return;
    }
    // A destination tap always means its root screen. StatefulShellRoute keeps
    // the last nested location of every branch; restoring that location here
    // could unexpectedly reopen `/publish` after the user had already left it.
    // Soft-refresh runs when [currentIndex] changes (see build).
    context.go(_branchRootPath(index));
  }

  static String _branchRootPath(int index) {
    switch (index) {
      case 0:
        return HomeScreen.routePath;
      case 1:
        return RoutesCatalogScreen.routePath;
      case 2:
        return RouteMatchScreen.routePath;
      case 3:
        return MyRoutesScreen.routePath;
      case 4:
        return ProfileScreen.routePath;
      default:
        return HomeScreen.routePath;
    }
  }

  static bool _isBranchRootPath(String path, int index) {
    switch (index) {
      case 0:
        return path == HomeScreen.routePath || path == '/';
      case 1:
        return path == RoutesCatalogScreen.routePath;
      case 2:
        return path == RouteMatchScreen.routePath;
      case 3:
        return path == MyRoutesScreen.routePath;
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final path = GoRouterState.of(context).uri.path;
    final aiChatActive = ref.watch(routeMatchAiModeProvider);
    final hideFloatingNav =
        path == '/profile/settings/support/chat' ||
        (path == RouteMatchScreen.routePath && aiChatActive);
    final detailNavigationIndex = _detailNavigationIndex(context);
    final guestProfile = _isGuestProfilePath(context, ref);
    final showDetailsChrome = detailNavigationIndex != null && !hideFloatingNav;
    final currentIndex = widget.navigationShell.currentIndex;
    if (currentIndex != _lastTabIndex) {
      _lastTabIndex = currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _softRefreshCurrentTab(currentIndex);
      });
    }
    final scrolledDown = ref.watch(tabScrolledDownProvider(currentIndex));
    // Route + place details share the Home-parked compact chrome and CTA.
    final showRouteAction = detailNavigationIndex == 0;
    final onTravelPlus = path.contains('/travel-plus');
    const detailActionLabel = 'Пройти маршрут';
    final VoidCallback? detailAction = showRouteAction
        ? () => _startRoute(context)
        : null;

    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.navigationShell,
          // Center-root screens keep the compact nav without the detail-page
          // readability scrim. Their own content already reserves nav space.
          if (showDetailsChrome &&
              detailNavigationIndex != _composeNavIndex &&
              !onTravelPlus)
            Positioned(
              key: const ValueKey('app-shell-bottom-scrim'),
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
          if (!hideFloatingNav)
            Positioned(
              left: AppSpacing.floatingNavInset,
              right: AppSpacing.floatingNavInset,
              bottom: bottomInset > 0 ? bottomInset : AppSpacing.sm,
              child: AppFloatingNavBar(
                key: _appFloatingNavKey,
                currentIndex: currentIndex,
                onTap: (index) => _onDestinationSelected(context, index),
                detailMode: showDetailsChrome,
                // Guest profile keeps the full nav; Home slot becomes history back.
                historyBackMode: guestProfile,
                scrollToTopMode: scrolledDown && !guestProfile,
                compactDestinationIndex: detailNavigationIndex ?? currentIndex,
                centerCompactMode: detailNavigationIndex == _composeNavIndex,
                onHistoryBack: () {
                  unawaited(AppHaptics.selectionClick());
                  if (context.canPop()) {
                    context.pop();
                  }
                },
                onStartRoute: detailAction,
                startRouteLabel: detailActionLabel,
                onPublishRoute: () {
                  unawaited(context.push('/publish'));
                },
                onMatchRoute: () {
                  widget.navigationShell.goBranch(2, initialLocation: true);
                },
              ),
            ),
          const InboxForegroundHost(),
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
    this.centerCompactMode = false,
    this.onHistoryBack,
    this.onStartRoute,
    this.startRouteLabel = 'Пройти маршрут',
    this.onPublishRoute,
    this.onMatchRoute,
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
  final bool centerCompactMode;
  final VoidCallback? onHistoryBack;
  final VoidCallback? onStartRoute;
  final String startRouteLabel;
  final VoidCallback? onPublishRoute;
  final VoidCallback? onMatchRoute;

  /// Only detail/settings chrome collapses the bar. Guest back keeps full nav.
  bool get compactChrome => detailMode;

  @override
  State<AppFloatingNavBar> createState() => _AppFloatingNavBarState();
}

class _AppFloatingNavBarState extends State<AppFloatingNavBar>
    with TickerProviderStateMixin {
  static const _height = 58.0;
  static const _detailHeight = 126.0;
  static const _composeHeight = 120.0;
  static const _activeDiameter = 58.0;
  static const _segmentGap = 10.0;
  static const _autoCollapseDelay = Duration(seconds: 5);

  late final AnimationController _positionController;
  late final AnimationController _detailPresenceController;
  late final AnimationController _detailExpansionController;
  late final AnimationController _composeController;
  late double _position;
  late double _fromPosition;
  late int _targetIndex;
  Timer? _autoCollapseTimer;

  /// After the user expands detail chrome once, a second tap on the parked
  /// compact droplet (Home on route details) exits to that destination.
  bool _compactExitArmed = false;

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
    _composeController = AnimationController(
      vsync: this,
      duration: AppMotion.composeMorph,
      reverseDuration: AppMotion.composeClose,
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
        _closeComposeMenu();
        _compactExitArmed = false;
        _detailExpansionController.value = 0;
        _animateTo(widget.compactDestinationIndex);
        _animateDetailPresence(1);
      } else {
        _cancelAutoCollapse();
        _compactExitArmed = false;
        _animateTo(widget.currentIndex);
        _animateDetailPresence(0);
        _detailExpansionController.value = 0;
      }
    } else if (widget.compactChrome &&
        widget.compactDestinationIndex != oldWidget.compactDestinationIndex) {
      _cancelAutoCollapse();
      _compactExitArmed = false;
      _detailExpansionController.value = 0;
      _animateTo(widget.compactDestinationIndex);
    } else if (!widget.compactChrome && widget.currentIndex != _targetIndex) {
      _closeComposeMenu();
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
    _composeController
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
        : AppPerf.motion(AppMotion.droplet);
    unawaited(_positionController.forward(from: 0));
  }

  void _animateDetailPresence(double target) {
    _detailPresenceController.duration = MediaQuery.disableAnimationsOf(context)
        ? AppMotion.reduced
        : AppPerf.motion(AppMotion.detailMorph);
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
        : AppPerf.motion(AppMotion.detailMorph);
    unawaited(AppHaptics.selectionClick());
    unawaited(
      _detailExpansionController.forward().then((_) {
        if (!mounted || !widget.detailMode) {
          return;
        }
        _compactExitArmed = true;
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
        : AppPerf.motion(AppMotion.detailMorph);
    unawaited(_detailExpansionController.reverse());
  }

  void _closeComposeMenu() {
    if (_composeController.value <= 0 && !_composeController.isAnimating) {
      return;
    }
    unawaited(
      _composeController.animateTo(
        0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? AppMotion.reduced
            : AppPerf.motion(AppMotion.composeClose),
        curve: Curves.linear,
      ),
    );
  }

  void _toggleComposeMenu() {
    if (widget.detailMode || widget.historyBackMode) {
      return;
    }
    unawaited(AppHaptics.selectionClick());
    final opening = _composeController.value < 0.5;
    _composeController.duration = MediaQuery.disableAnimationsOf(context)
        ? AppMotion.reduced
        : AppPerf.motion(AppMotion.composeMorph);
    _composeController.reverseDuration = MediaQuery.disableAnimationsOf(context)
        ? AppMotion.reduced
        : AppPerf.motion(AppMotion.composeClose);
    unawaited(
      _composeController.animateTo(
        opening ? 1 : 0,
        duration: opening
            ? _composeController.duration
            : _composeController.reverseDuration,
        curve: Curves.linear,
      ),
    );
  }

  void _handleTap(int index) {
    // Guest profile: Home slot is history-back (same as edge swipe).
    if (widget.historyBackMode && index == 0) {
      widget.onHistoryBack?.call();
      return;
    }
    if (!widget.detailMode && index == _composeNavIndex) {
      _toggleComposeMenu();
      return;
    }
    if (_composeController.value > 0.01) {
      _closeComposeMenu();
    }
    // Expand-in-place only when the parked droplet IS the current branch
    // (Profile→Settings). Route details park Home while current=Routes, so
    // Home must navigate immediately once the bar is open.
    final parkedOnCurrentBranch =
        widget.compactDestinationIndex == widget.currentIndex;
    if (widget.detailMode &&
        _detailExpansionController.value < 1 &&
        index == widget.compactDestinationIndex &&
        parkedOnCurrentBranch) {
      _expandDetailNavigation();
      return;
    }
    // Any tap on the expanded menu postpones auto-collapse.
    if (widget.detailMode && _detailExpansionController.value > 0.5) {
      _scheduleAutoCollapse();
    }
    if (index != widget.currentIndex) {
      unawaited(AppHaptics.selectionClick());
      _animateTo(index);
    }
    widget.onTap(index);
  }

  void _handleCompactOverlayTap() {
    // Parked away from the current branch (Home on route details):
    // 1st tap expands; 2nd tap (armed, or mid-expand) exits via onTap→go.
    final parkedAway = widget.compactDestinationIndex != widget.currentIndex;
    if (parkedAway &&
        (_compactExitArmed || _detailExpansionController.value > 0.35)) {
      unawaited(AppHaptics.selectionClick());
      _animateTo(widget.compactDestinationIndex);
      widget.onTap(widget.compactDestinationIndex);
      return;
    }
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
    final composeT = _composeController.value;
    final compactProgress = presence * (1 - expanded);
    final showDetailLayout =
        widget.compactChrome ||
        _detailPresenceController.isAnimating ||
        presence > 0.001;
    final hasDetailAction = widget.detailMode && widget.onStartRoute != null;
    final showCompose =
        !widget.detailMode &&
        (composeT > 0.001 || _composeController.isAnimating);
    final totalHeight = showDetailLayout && hasDetailAction
        ? _detailHeight
        : showCompose
        ? _height +
              (_composeHeight - _height) *
                  Curves.easeOutCubic.transform(composeT)
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
            final ctaInset = (_activeDiameter + _segmentGap) * (1 - widenT);
            final ctaTop = (_detailHeight - _height) * (1 - riseT);
            // ~13% narrower than the track next to the compact droplet.
            final ctaTrack = math.max(0.0, width - ctaInset);
            final ctaSidePad = ctaTrack * 0.065;
            // Two droplets rise out of the live "+" center, split, then settle
            // into capsules. Keep phase linear here; the painter owns motion
            // timing so geometry, hit targets and labels never double-ease.
            final composeTClamped = composeT.clamp(0.0, 1.0);
            final leftPhase = reduceMotion
                ? Curves.easeOut.transform(composeTClamped)
                : (composeTClamped / 0.94).clamp(0.0, 1.0);
            final rightPhase = reduceMotion
                ? leftPhase
                : ((composeTClamped - 0.055) / 0.945).clamp(0.0, 1.0);
            const composeGap = 8.0;
            const composeBtnHeight = 48.0;
            final composeBtnWidth = (width - composeGap) / 2;
            final plusCenterX =
                (_composeNavIndex + 0.5) * (width / _appNavDestinationCount);
            final plusCenterY = totalHeight - _height / 2;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (showCompose)
                  Positioned.fill(
                    key: const ValueKey('nav-compose-actions'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _ComposeLiquidPainter(
                                leftProgress: leftPhase,
                                rightProgress: rightPhase,
                                origin: Offset(plusCenterX, plusCenterY),
                                leftTarget: Offset(
                                  composeBtnWidth / 2,
                                  composeBtnHeight / 2,
                                ),
                                rightTarget: Offset(
                                  composeBtnWidth +
                                      composeGap +
                                      composeBtnWidth / 2,
                                  composeBtnHeight / 2,
                                ),
                                buttonWidth: composeBtnWidth,
                                buttonHeight: composeBtnHeight,
                                // Match nav active fill so compose CTAs sit with the bar.
                                color: AppColors.activeNavigationFill,
                                reduceMotion: reduceMotion,
                              ),
                            ),
                          ),
                        ),
                        _ComposeDropletHitTarget(
                          label: 'Опубликовать',
                          progress: leftPhase,
                          width: composeBtnWidth,
                          height: composeBtnHeight,
                          left: 0,
                          onTap: () {
                            _closeComposeMenu();
                            widget.onPublishRoute?.call();
                          },
                        ),
                        _ComposeDropletHitTarget(
                          label: 'Подобрать',
                          progress: rightPhase,
                          width: composeBtnWidth,
                          height: composeBtnHeight,
                          left: composeBtnWidth + composeGap,
                          onTap: () {
                            _closeComposeMenu();
                            widget.onMatchRoute?.call();
                          },
                        ),
                      ],
                    ),
                  ),
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
    final centerCompact = widget.centerCompactMode && widget.compactChrome;
    final regularActiveCenterX = (_position + 0.5) * slotWidth;
    final regularFromCenterX = (_fromPosition + 0.5) * slotWidth;
    final compactCenterX = centerCompact
        ? width - _activeDiameter / 2
        : floatingNavCompactCenterX(
            width: width,
            compactDestinationIndex: widget.compactDestinationIndex,
          );
    // The center branch has two independent two-item glass groups. Collapse
    // those first; only after they have folded into their own centers does the
    // active "+" droplet park on the right. Expansion is the exact reverse.
    final groupCollapse = centerCompact
        ? Curves.easeInOutCubic.transform(
            (compactProgress / 0.68).clamp(0.0, 1.0),
          )
        : compactProgress;
    final activePark = centerCompact
        ? Curves.easeInOutCubicEmphasized.transform(
            ((compactProgress - 0.5) / 0.5).clamp(0.0, 1.0),
          )
        : compactProgress;
    final activeCenterX = lerpDouble(
      regularActiveCenterX,
      compactCenterX,
      activePark,
    )!;
    final fromCenterX = lerpDouble(
      regularFromCenterX,
      compactCenterX,
      activePark,
    )!;
    final regularLeadingEnd = centerCompact
        ? _composeNavIndex * slotWidth - _segmentGap / 2
        : math.max(0.0, _position * slotWidth - _segmentGap / 2);
    final leadingFoldX = regularLeadingEnd / 2;
    final leadingStart = centerCompact
        ? lerpDouble(0, leadingFoldX, groupCollapse)!
        : lerpDouble(0, compactCenterX, compactProgress)!;
    final leadingEnd = centerCompact
        ? lerpDouble(regularLeadingEnd, leadingFoldX, groupCollapse)!
        : lerpDouble(regularLeadingEnd, compactCenterX, compactProgress)!;
    final regularTrailingLeft = centerCompact
        ? (_composeNavIndex + 1) * slotWidth + _segmentGap / 2
        : math.min(width, (_position + 1) * slotWidth + _segmentGap / 2);
    final trailingFoldX = (regularTrailingLeft + width) / 2;
    final trailingStart = centerCompact
        ? lerpDouble(regularTrailingLeft, trailingFoldX, groupCollapse)!
        : lerpDouble(regularTrailingLeft, compactCenterX, compactProgress)!;
    final trailingEnd = centerCompact
        ? lerpDouble(width, trailingFoldX, groupCollapse)!
        : lerpDouble(width, compactCenterX, compactProgress)!;
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
                            : centerCompact
                            ? (1 - groupCollapse).clamp(0.0, 1.0)
                            : ((revealProgress -
                                          (index - widget.compactDestinationIndex)
                                                  .abs() *
                                              0.04) /
                                      0.78)
                                  .clamp(0, 1),
                        translationX: centerCompact
                            ? index == widget.compactDestinationIndex
                                  ? activeCenterX - (index + 0.5) * slotWidth
                                  : ((index < _composeNavIndex
                                                ? leadingFoldX
                                                : trailingFoldX) -
                                            (index + 0.5) * slotWidth) *
                                        groupCollapse
                            : (compactCenterX - (index + 0.5) * slotWidth) *
                                  compactProgress,
                        showHistoryBack: widget.historyBackMode && index == 0,
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

/// Transparent hit target + fading label over the painted liquid blob.
class _ComposeDropletHitTarget extends StatelessWidget {
  const _ComposeDropletHitTarget({
    required this.label,
    required this.progress,
    required this.width,
    required this.height,
    required this.left,
    required this.onTap,
  });

  final String label;
  final double progress;
  final double width;
  final double height;
  final double left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final labelT = Curves.easeOutCubic.transform(
      ((t - 0.52) / 0.34).clamp(0.0, 1.0),
    );
    final settle = Curves.easeOutBack.transform(
      ((t - 0.42) / 0.58).clamp(0.0, 1.0),
    );

    return Positioned(
      key: ValueKey('nav-compose-action-$label'),
      left: left,
      width: width,
      top: 0,
      height: height,
      child: IgnorePointer(
        ignoring: t < 0.64,
        child: Semantics(
          hidden: t < 0.64,
          button: true,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadii.capsule),
              child: Center(
                child: Transform.scale(
                  scaleX: 0.94 + 0.06 * settle,
                  scaleY: 0.88 + 0.12 * settle,
                  child: Opacity(
                    key: ValueKey('nav-compose-label-$label'),
                    opacity: labelT,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.button.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

/// Paints two controlled liquid morphs from the live "+" center.
///
/// The geometry has one owner: the controller only supplies a linear phase,
/// while this painter stages rise, lateral split, elastic deformation and the
/// retracting neck. That keeps opening and closing perfectly reversible.
class _ComposeLiquidPainter extends CustomPainter {
  const _ComposeLiquidPainter({
    required this.leftProgress,
    required this.rightProgress,
    required this.origin,
    required this.leftTarget,
    required this.rightTarget,
    required this.buttonWidth,
    required this.buttonHeight,
    required this.color,
    required this.reduceMotion,
  });

  final double leftProgress;
  final double rightProgress;
  final Offset origin;
  final Offset leftTarget;
  final Offset rightTarget;
  final double buttonWidth;
  final double buttonHeight;
  final Color color;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final sourcePhase = math.max(leftProgress, rightProgress);
    final sourceRelease = Curves.easeInCubic.transform(
      _interval(sourcePhase, 0.04, 0.58),
    );
    final sourceRadius = lerpDouble(12, 0, sourceRelease)!;
    if (!reduceMotion && sourceRadius > 0.5) {
      canvas.drawCircle(origin, sourceRadius, paint);
    }

    _paintBlob(
      canvas,
      paint,
      progress: leftProgress,
      target: leftTarget,
      goingLeft: true,
    );
    _paintBlob(
      canvas,
      paint,
      progress: rightProgress,
      target: rightTarget,
      goingLeft: false,
    );
  }

  void _paintBlob(
    Canvas canvas,
    Paint paint, {
    required double progress,
    required Offset target,
    required bool goingLeft,
  }) {
    final t = progress.clamp(0.0, 1.0);
    if (t <= 0.001) {
      return;
    }

    final verticalFlight = reduceMotion
        ? Curves.easeOut.transform(t)
        : AppMotion.liquidOut.transform(_interval(t, 0, 0.82));
    final horizontalFlight = reduceMotion
        ? verticalFlight
        : const Cubic(0.58, 0, 0.34, 1).transform(_interval(t, 0.2, 1));
    final center = Offset(
      lerpDouble(origin.dx, target.dx, horizontalFlight)!,
      lerpDouble(origin.dy, target.dy, verticalFlight)!,
    );

    final widthT = Curves.easeOutCubic.transform(_interval(t, 0.12, 0.9));
    final heightT = Curves.easeOutCubic.transform(_interval(t, 0.02, 0.72));
    final deformation = reduceMotion
        ? 0.0
        : math.sin(math.pi * _interval(t, 0.04, 0.82));
    final width =
        lerpDouble(22, buttonWidth, widthT)! * (1 - deformation * 0.055);
    final height =
        lerpDouble(22, buttonHeight, heightT)! * (1 + deformation * 0.16);
    final tail = reduceMotion
        ? 0.0
        : deformation *
              (1 - Curves.easeInCubic.transform(_interval(t, 0.5, 0.9)));

    if (!reduceMotion && t < 0.78) {
      _paintNeck(
        canvas,
        paint,
        progress: t,
        center: center,
        blobHeight: height,
      );
    }
    canvas.drawPath(
      _dropletCapsulePath(
        center: center,
        width: width,
        height: height,
        origin: origin,
        tail: tail,
        innerSide: goingLeft ? 1.0 : -1.0,
      ),
      paint,
    );
  }

  void _paintNeck(
    Canvas canvas,
    Paint paint, {
    required double progress,
    required Offset center,
    required double blobHeight,
  }) {
    final vector = center - origin;
    final distance = vector.distance;
    if (distance < 1) {
      return;
    }
    final activity = math.sin(math.pi * _interval(progress, 0.02, 0.76));
    if (activity <= 0.01) {
      return;
    }
    final direction = vector / distance;
    final normal = Offset(-direction.dy, direction.dx);
    final end = center - direction * blobHeight * 0.2;
    final originHalf =
        lerpDouble(8.5, 1.2, _interval(progress, 0.1, 0.74))! * activity;
    final endHalf = blobHeight * 0.16 * activity;
    final c1 = Offset.lerp(origin, end, 0.34)!;
    final c2 = Offset.lerp(origin, end, 0.76)!;
    final originA = origin + normal * originHalf;
    final originB = origin - normal * originHalf;
    final endA = end + normal * endHalf;
    final endB = end - normal * endHalf;

    final path = Path()
      ..moveTo(originA.dx, originA.dy)
      ..cubicTo(
        (c1 + normal * originHalf).dx,
        (c1 + normal * originHalf).dy,
        (c2 + normal * endHalf).dx,
        (c2 + normal * endHalf).dy,
        endA.dx,
        endA.dy,
      )
      ..lineTo(endB.dx, endB.dy)
      ..cubicTo(
        (c2 - normal * endHalf).dx,
        (c2 - normal * endHalf).dy,
        (c1 - normal * originHalf).dx,
        (c1 - normal * originHalf).dy,
        originB.dx,
        originB.dy,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = paint.color.withValues(alpha: 0.78 * activity)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  static Path _dropletCapsulePath({
    required Offset center,
    required double width,
    required double height,
    required Offset origin,
    required double tail,
    required double innerSide,
  }) {
    final capsule = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: width, height: height),
          Radius.circular(height / 2),
        ),
      );
    if (tail <= 0.01) {
      return capsule;
    }
    final vector = origin - center;
    final distance = vector.distance;
    if (distance < 1) {
      return capsule;
    }
    final direction = vector / distance;
    final normal = Offset(-direction.dy, direction.dx);
    final sideBias = normal * innerSide * width * 0.09;
    final anchor = center + direction * height * 0.34 + sideBias;
    final halfBase = height * 0.18 * tail;
    final tip = anchor + direction * height * (0.18 + 0.34 * tail);
    final edgeA = anchor + normal * halfBase;
    final edgeB = anchor - normal * halfBase;
    capsule.addPath(
      Path()
        ..moveTo(edgeA.dx, edgeA.dy)
        ..quadraticBezierTo(tip.dx, tip.dy, edgeB.dx, edgeB.dy)
        ..close(),
      Offset.zero,
    );
    return capsule;
  }

  static double _interval(double value, double begin, double end) {
    return ((value - begin) / (end - begin)).clamp(0.0, 1.0);
  }

  @override
  bool shouldRepaint(covariant _ComposeLiquidPainter oldDelegate) {
    return oldDelegate.leftProgress != leftProgress ||
        oldDelegate.rightProgress != rightProgress ||
        oldDelegate.origin != origin ||
        oldDelegate.leftTarget != leftTarget ||
        oldDelegate.rightTarget != rightTarget ||
        oldDelegate.buttonWidth != buttonWidth ||
        oldDelegate.buttonHeight != buttonHeight ||
        oldDelegate.color != color ||
        oldDelegate.reduceMotion != reduceMotion;
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
