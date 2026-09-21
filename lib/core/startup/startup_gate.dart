import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/performance/app_perf.dart';
import 'package:tourism_mobile/core/startup/krymtrip_logo.dart';
import 'package:tourism_mobile/core/startup/splash_frames.dart';
import 'package:tourism_mobile/core/startup/startup_config.dart';
import 'package:tourism_mobile/core/startup/startup_readiness.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/onboarding/presentation/welcome_screen.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// The night the native launch screen starts from (`#0A1630`).
const startupNavy = Color(0xFF0A1630);

/// Logo width in dp; the native launch screen draws it at the same size and
/// position so the hand-over from native to Flutter does not jump.
const startupLogoWidth = 168.0;

/// The preloader: an opaque layer over the router that plays a sunrise while
/// the session is checked and the first screen's data is warmed, then fades
/// out onto whichever screen the person belongs on. Shown once per process.
///
/// It is not a route: the router underneath is untouched (its redirect keeps
/// returning null until the session is known) and only stops animating,
/// speaking to screen readers and taking taps while the gate is up.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate>
    with SingleTickerProviderStateMixin {
  final _progress = ValueNotifier<double>(0);
  final _frameTick = ValueNotifier<int>(0);
  final _hint = ValueNotifier<bool>(false);
  final _frames = List<LoadedFrame?>.filled(4, null);

  Ticker? _ticker;
  double _milestone = 0;
  Duration _lastElapsed = Duration.zero;
  late final bool _reduceMotion;
  late final StartupTiming _timing;
  var _active = false;
  var _closing = false;

  @override
  void initState() {
    super.initState();
    _active =
        ref.read(startupGateEnabledProvider) &&
        ref.read(startupGateOpenProvider);
    if (!_active) {
      return;
    }
    _timing = ref.read(startupTimingProvider);
    _reduceMotion =
        AppMotion.reduceMotion ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
    SplashFrames.keepDayAlive();
    if (_reduceMotion) {
      _progress.value = 1;
    } else {
      final ticker = createTicker(_onTick);
      _ticker = ticker;
      unawaited(ticker.start());
    }
    unawaited(_loadFrames());
    unawaited(_run());
  }

  @override
  void dispose() {
    _ticker?.dispose();
    for (final frame in _frames) {
      frame?.dispose();
    }
    _progress.dispose();
    _frameTick.dispose();
    _hint.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    final minimum = _timing.minimum.inMicroseconds / 1e6;
    // Never ahead of the clock (a fast start must not skip the sunrise) and
    // never ahead of what has actually been loaded.
    final target = math.min(_milestone, elapsed.inMicroseconds / 1e6 / minimum);
    final next =
        _progress.value + (target - _progress.value) * (1 - math.exp(-dt * 7));
    _progress.value = next.clamp(0.0, 1.0);
  }

  /// Night first (the native launch screen already shows the same colour),
  /// then the rest in order; one decode at a time keeps the first frames free.
  Future<void> _loadFrames() async {
    final order = _reduceMotion ? const [3] : const [0, 3, 1, 2];
    for (final index in order) {
      final frame = await LoadedFrame.load(SplashFrames.all[index]);
      if (!mounted) {
        frame?.dispose();
        return;
      }
      _frames[index] = frame;
      _frameTick.value++;
    }
  }

  StartupDeps _deps() {
    final session = ref.read(sessionProvider.notifier);
    return StartupDeps(
      isHydrated: () => ref.read(sessionProvider).isHydrated,
      isAuthenticated: () => ref.read(sessionProvider).isAuthenticated,
      sessionSettled: () {
        final done = Completer<void>();
        final sub = ref.listenManual<SessionState>(sessionProvider, (_, next) {
          if (next.isHydrated && !done.isCompleted) {
            done.complete();
          }
        });
        if (ref.read(sessionProvider).isHydrated && !done.isCompleted) {
          done.complete();
        }
        return done.future.whenComplete(sub.close);
      },
      enterProvisional: session.enterProvisional,
      catalogReady: () async {
        try {
          await ref.read(homeRoutesProvider.future);
        } on Object {
          // A failed catalog is the home screen's to show.
        }
      },
      coversReady: _warmCovers,
    );
  }

  Future<void> _warmCovers() async {
    try {
      final page = await ref.read(homeRoutesProvider.future);
      if (!mounted) {
        return;
      }
      final config = ref.read(appConfigProvider);
      final routes = page.items.take(AppPerf.preferCheapEffects ? 5 : 7);
      await Future.wait([
        for (final route in routes)
          if (AppImages.routeCoverProvider(
                config: config,
                coverImageUrl: route.coverImageUrl,
                fallbackSeed: route.slug,
                cacheWidth: 1080,
              )
              case final provider?)
            precacheImage(provider, context).catchError((Object _) {}),
      ]);
    } on Object {
      // Covers are best effort.
    }
  }

  Future<void> _run() async {
    final minimum = Future<void>.delayed(
      _reduceMotion ? Duration.zero : _timing.minimum,
    );
    final result = await runStartup(
      deps: _deps(),
      timing: _timing,
      onMilestone: (value) => _milestone = value,
      onSlowHint: (visible) => _hint.value = visible,
    );
    await minimum;
    if (!mounted) {
      return;
    }
    await _waitForRouter(result.authenticated);
    if (!mounted) {
      return;
    }
    setState(() => _closing = true);
    // A cross-fade with nothing to fade (reduce-motion) has no end callback.
    if (_fadeDuration == Duration.zero) {
      _finish();
    }
  }

  /// Closes only once the router already shows the target screen: an
  /// authenticated person must not glimpse Welcome, a guest must not see a
  /// blank router.
  Future<void> _waitForRouter(bool authenticated) async {
    final router = ref.read(appRouterProvider);
    bool onTarget() {
      final onWelcome =
          router.routeInformationProvider.value.uri.path ==
          WelcomeScreen.routePath;
      return authenticated ? !onWelcome : onWelcome;
    }

    if (onTarget()) {
      return;
    }
    final done = Completer<void>();
    void listener() {
      if (onTarget() && !done.isCompleted) {
        done.complete();
      }
    }

    router.routeInformationProvider.addListener(listener);
    try {
      await Future.any<void>([
        done.future,
        Future<void>.delayed(_timing.routerSettle),
      ]);
    } finally {
      router.routeInformationProvider.removeListener(listener);
    }
  }

  Duration get _fadeDuration => _reduceMotion ? Duration.zero : _timing.fade;

  void _finish() {
    if (!mounted) {
      return;
    }
    _ticker?.stop();
    // Everything but «day» goes: it is held for Welcome, the rest is ~19 MB.
    for (var i = 0; i < _frames.length; i++) {
      if (i != 3) {
        _frames[i]?.dispose();
        _frames[i] = null;
        PaintingBinding.instance.imageCache.evict(SplashFrames.all[i]);
      }
    }
    // Riverpod forbids changing a provider while the tree builds.
    unawaited(
      Future<void>.microtask(() {
        if (mounted) {
          ref.read(startupGateOpenProvider.notifier).state = false;
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final open = ref.watch(startupGateOpenProvider);
    final showOverlay = _active && open;
    // While the gate is up the screen below neither speaks to screen readers,
    // nor animates, nor takes taps; it wakes up as the fade starts.
    final covered = showOverlay && !_closing;
    // The same wrappers stay in place after the gate is gone (only their flags
    // flip), so the router's Navigator below is never re-created — a different
    // tree shape would remount the whole app and flash the skeletons.
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: covered,
          child: TickerMode(
            enabled: !covered,
            child: IgnorePointer(ignoring: covered, child: widget.child),
          ),
        ),
        if (showOverlay)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _closing ? 0 : 1,
                duration: _fadeDuration,
                onEnd: _finish,
                child: _GateView(
                  progress: _progress,
                  frameTick: _frameTick,
                  hint: _hint,
                  frames: _frames,
                  zoom: !AppPerf.preferCheapEffects && !_reduceMotion,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GateView extends StatelessWidget {
  const _GateView({
    required this.progress,
    required this.frameTick,
    required this.hint,
    required this.frames,
    required this.zoom,
  });

  final ValueNotifier<double> progress;
  final ValueNotifier<int> frameTick;
  final ValueNotifier<bool> hint;
  final List<LoadedFrame?> frames;
  final bool zoom;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ValueListenableBuilder<bool>(
        valueListenable: hint,
        builder: (context, slow, _) => Semantics(
          container: true,
          liveRegion: true,
          label: slow ? 'Проверяем соединение' : 'Загрузка',
          child: ExcludeSemantics(
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _BackdropPainter(
                      progress: progress,
                      frameTick: frameTick,
                      frames: frames,
                      zoom: zoom,
                    ),
                  ),
                ),
                const Center(child: KrymtripLogo(width: startupLogoWidth)),
                if (slow)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: MediaQuery.paddingOf(context).bottom + 48,
                    child: Text(
                      'Проверяем соединение',
                      textAlign: TextAlign.center,
                      style: AppTypography.welcomeSubtitle.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
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

/// Draws the four backdrops as a chain of cross-fades. Everything is painted
/// straight to the canvas with a per-image alpha: no widget rebuilds and no
/// full-screen `saveLayer`, which is what makes this cheap on Mali GPUs.
class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.progress,
    required this.frameTick,
    required this.frames,
    required this.zoom,
  }) : super(repaint: Listenable.merge([progress, frameTick]));

  final ValueNotifier<double> progress;
  final ValueNotifier<int> frameTick;
  final List<LoadedFrame?> frames;
  final bool zoom;

  static double _smooth(double t) => t * t * (3 - 2 * t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = startupNavy);
    final p = progress.value.clamp(0.0, 1.0);
    final position = Curves.easeInOutSine.transform(p) * 3;

    final alphas = [
      1.0,
      for (var i = 1; i < 4; i++) _smooth((position - (i - 1)).clamp(0.0, 1.0)),
    ];
    // Layers under a fully opaque one are invisible: skip them.
    var first = 0;
    for (var i = 3; i > 0; i--) {
      if (alphas[i] >= 0.999 && frames[i] != null) {
        first = i;
        break;
      }
    }

    canvas.save();
    if (zoom) {
      final scale = 1.02 + 0.06 * (1 - Curves.easeOutCubic.transform(p));
      canvas
        ..translate(size.width / 2, size.height / 2)
        ..scale(scale)
        ..translate(-size.width / 2, -size.height / 2);
    }
    for (var i = first; i < 4; i++) {
      final frame = frames[i];
      if (frame == null || alphas[i] <= 0) {
        continue;
      }
      paintImage(
        canvas: canvas,
        rect: rect,
        image: frame.image,
        fit: BoxFit.cover,
        // Same alignment as the welcome screen's backdrop, so the hand-over
        // is seamless.
        alignment: const Alignment(-0.12, 0),
        opacity: alphas[i],
        filterQuality: FilterQuality.medium,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => false;
}
