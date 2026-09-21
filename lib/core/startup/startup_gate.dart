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
import 'package:tourism_mobile/core/startup/splash_scene_layout.dart';
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
  LoadedScene? _scene;

  /// The flattened day picture: reduce-motion shows only this, and it is the
  /// fallback when a layer fails to load.
  LoadedFrame? _dayFrame;

  /// Completes once the drawn scene has reached full daylight, so the gate
  /// never fades out onto Welcome from a darker frame.
  final _reachedDay = Completer<void>();

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
      _reachedDay.complete();
    }
    unawaited(_loadScene());
    unawaited(_run());
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _scene?.dispose();
    _dayFrame?.dispose();
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
    if (_progress.value >= 0.998 && !_reachedDay.isCompleted) {
      _progress.value = 1;
      _reachedDay.complete();
    }
  }

  /// The day picture first (the fallback, and all reduce-motion needs), then
  /// the layers. The sunrise starts only once every layer is decoded, so no
  /// layer can pop in half-way; until then the night sky and the logo show,
  /// which is what the native launch screen already looks like.
  Future<void> _loadScene() async {
    final day = await LoadedFrame.load(SplashFrames.day);
    if (!mounted) {
      day?.dispose();
      return;
    }
    _dayFrame = day;
    _frameTick.value++;
    if (_reduceMotion) {
      return;
    }
    final scene = await LoadedScene.load();
    if (!mounted) {
      scene?.dispose();
      return;
    }
    if (scene == null) {
      // Show the day picture straight away rather than a broken sunrise.
      _progress.value = 1;
      if (!_reachedDay.isCompleted) _reachedDay.complete();
      _frameTick.value++;
      return;
    }
    _scene = scene;
    _frameTick.value++;
    final ticker = createTicker(_onTick);
    _ticker = ticker;
    unawaited(ticker.start());
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
    // Let a running sunrise finish (it eases in), so the gate never fades
    // onto Welcome from a darker frame. If the layers are not even decoded
    // yet there is nothing to finish: the day picture is shown instead.
    if (_ticker != null && !_reachedDay.isCompleted) {
      final cutoff = Completer<void>();
      final timer = Timer(const Duration(milliseconds: 1500), cutoff.complete);
      await Future.any<void>([_reachedDay.future, cutoff.future]);
      timer.cancel();
    }
    if (!mounted) {
      return;
    }
    _progress.value = 1;
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
    // The layers (~11 MB decoded) go; «day» stays held for Welcome.
    _scene?.dispose();
    _scene = null;
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
                  scene: () => _scene,
                  dayFrame: () => _dayFrame,
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
    required this.scene,
    required this.dayFrame,
  });

  final ValueNotifier<double> progress;
  final ValueNotifier<int> frameTick;
  final ValueNotifier<bool> hint;
  final LoadedScene? Function() scene;
  final LoadedFrame? Function() dayFrame;

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
                    painter: _ScenePainter(
                      progress: progress,
                      frameTick: frameTick,
                      scene: scene,
                      dayFrame: dayFrame,
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

/// Draws the preloader scene: one picture built from the designer's layers,
/// lit from night to day. The layers2 landscape stays still; clouds catch
/// the first light, the sun clears the horizon, then the foreground warms.
///
/// Everything is drawn straight to the canvas with per-image paint (colour
/// matrix and alpha): no widget rebuilds and no full-screen `saveLayer`.
class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.progress,
    required this.frameTick,
    required this.scene,
    required this.dayFrame,
  }) : super(repaint: Listenable.merge([progress, frameTick]));

  final ValueNotifier<double> progress;
  final ValueNotifier<int> frameTick;
  final LoadedScene? Function() scene;
  final LoadedFrame? Function() dayFrame;

  // Sky colours sampled from the designer's night and dusk pictures, at the
  // same heights (fractions of the 1672 px canvas) down to the horizon.
  static const _skyStops = [0.0, 0.18, 0.36, 0.48, 0.57, 0.65, 0.70, 1.0];
  static const _nightSky = [
    Color(0xFF0B1A31),
    Color(0xFF09182F),
    Color(0xFF0A1C34),
    Color(0xFF0D213C),
    Color(0xFF1F304C),
    Color(0xFF494858),
    Color(0xFFB47E68),
    Color(0xFFB47E68),
  ];
  static const _duskSky = [
    Color(0xFF0E264A),
    Color(0xFF0F2650),
    Color(0xFF193867),
    Color(0xFF46587E),
    Color(0xFFAD8998),
    Color(0xFFFFAF7D),
    Color(0xFFFFDA90),
    Color(0xFFFFDA90),
  ];

  static const _identity = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// Darkened, bluish and partly desaturated: moonlight.
  static final _night = _lightMatrix(
    scale: const [0.18, 0.24, 0.37],
    add: const [2, 7, 17],
    desaturate: 0.65,
  );

  /// Warm and still dim: the first light before sunrise.
  static final _dusk = _lightMatrix(
    scale: const [0.66, 0.52, 0.68],
    add: const [8, 3, 10],
    desaturate: 0.28,
  );

  static List<double> _lightMatrix({
    required List<double> scale,
    required List<double> add,
    required double desaturate,
  }) {
    const lum = [0.2126, 0.7152, 0.0722];
    final m = <double>[];
    for (var c = 0; c < 3; c++) {
      for (var i = 0; i < 3; i++) {
        final keep = i == c ? 1 - desaturate : 0.0;
        m.add(scale[c] * (keep + desaturate * lum[i]));
      }
      m
        ..add(0)
        ..add(add[c]);
    }
    m.addAll(const [0, 0, 0, 1, 0]);
    return m;
  }

  static List<double> _lerp(List<double> a, List<double> b, double t) => [
    for (var i = 0; i < a.length; i++) a[i] + (b[i] - a[i]) * t,
  ];

  static double _smooth(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value.clamp(0.0, 1.0);
    final loaded = scene();
    final day = dayFrame();

    // Match SplashDayBackdrop: fit width, anchor the coast to the bottom.
    // Extra height is sky, so both the sun and tourists stay inside the frame.
    final scale = size.width / splashSceneWidth;
    final dh = splashSceneHeight * scale;
    final dy = size.height - dh;
    final firstLight = _smooth((t - 0.06) / 0.42);
    final daylight = _smooth((t - 0.48) / 0.52);
    final topColor = Color.lerp(
      Color.lerp(_nightSky.first, _duskSky.first, firstLight),
      SplashFrames.daySkyColor,
      daylight,
    )!;

    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..drawRect(Offset.zero & size, Paint()..color = topColor);
    canvas
      ..translate(0, dy)
      ..scale(scale);
    const sceneRect = Rect.fromLTWH(0, 0, splashSceneWidth, splashSceneHeight);

    if (loaded == null) {
      // Layers not decoded yet (or failed): the night sky, or the finished
      // day picture once the gate is about to hand over.
      if (t >= 1 && day != null) {
        paintImage(
          canvas: canvas,
          rect: sceneRect,
          image: day.image,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
        );
      } else {
        _paintGradient(canvas, sceneRect, _nightSky, 1);
      }
      canvas.restore();
      return;
    }

    final light = ColorFilter.matrix(
      _lerp(_lerp(_night, _dusk, firstLight), _identity, daylight),
    );

    // Sky: the day gradient, with dusk and night laid over it and fading.
    paintImage(
      canvas: canvas,
      rect: sceneRect,
      image: loaded.sky.image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
    _paintGradient(canvas, sceneRect, _duskSky, 1 - daylight);
    _paintGradient(canvas, sceneRect, _nightSky, 1 - firstLight);

    for (var i = 0; i < splashSceneLayers.length; i++) {
      final layer = splashSceneLayers[i];
      final image = loaded.layers[i].image;
      final x = layer.left;
      var y = layer.top;
      var opacity = 1.0;
      ColorFilter? filter = light;
      switch (layer.name) {
        case 'sun':
          // Rises from behind the sea and the mountains, which are drawn
          // after it; it is light, so it keeps its own colour.
          y += 42 * (1 - _smooth((t - 0.35) / 0.55));
          opacity = _smooth((t - 0.32) / 0.30);
          filter = null;
        case 'clouds':
          // The thin clouds light up ahead of the ground.
          filter = ColorFilter.matrix(
            _lerp(_night, _identity, _smooth((t - 0.08) / 0.68)),
          );
        case 'tourists':
          opacity = _smooth((t - 0.48) / 0.38);
      }
      if (opacity <= 0) {
        continue;
      }
      canvas.drawImage(
        image,
        Offset(x, y),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = filter
          ..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    }
    canvas.restore();
  }

  void _paintGradient(
    Canvas canvas,
    Rect rect,
    List<Color> colors,
    double opacity,
  ) {
    if (opacity <= 0.001) {
      return;
    }
    canvas.drawRect(
      // Cover the fractional image edge too: otherwise its bright day sky
      // can leave a one-pixel line against the extended night sky.
      rect.inflate(2),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [for (final c in colors) c.withValues(alpha: opacity)],
          stops: _skyStops,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ScenePainter old) => false;
}

/// The preloader scene frozen at [progress] (0 night, 1 day), without the
/// logo. For tests and design checks.
@visibleForTesting
class SplashScenePreview extends StatefulWidget {
  const SplashScenePreview({required this.progress, super.key});

  final double progress;

  @override
  State<SplashScenePreview> createState() => _SplashScenePreviewState();
}

class _SplashScenePreviewState extends State<SplashScenePreview> {
  late final _progress = ValueNotifier<double>(widget.progress);
  final _tick = ValueNotifier<int>(0);
  LoadedScene? _scene;
  LoadedFrame? _day;

  /// Completes once the layers are decoded (tests wait on it).
  final loaded = Completer<void>();

  @override
  void initState() {
    super.initState();
    unawaited(() async {
      final scene = await LoadedScene.load();
      final day = await LoadedFrame.load(SplashFrames.day);
      if (!mounted) {
        scene?.dispose();
        day?.dispose();
        return;
      }
      _scene = scene;
      _day = day;
      _tick.value++;
      loaded.complete();
    }());
  }

  @override
  void didUpdateWidget(SplashScenePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _progress.value = widget.progress;
  }

  @override
  void dispose() {
    _scene?.dispose();
    _day?.dispose();
    _progress.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _ScenePainter(
      progress: _progress,
      frameTick: _tick,
      scene: () => _scene,
      dayFrame: () => _day,
    ),
  );
}
