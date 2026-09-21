import 'dart:async';

import 'package:tourism_mobile/core/startup/startup_config.dart';

/// What the start-up waits on. Injected so the timing logic is testable
/// without a router, a network or real images.
class StartupDeps {
  const StartupDeps({
    required this.isHydrated,
    required this.isAuthenticated,
    required this.sessionSettled,
    required this.enterProvisional,
    required this.catalogReady,
    required this.coversReady,
  });

  final bool Function() isHydrated;
  final bool Function() isAuthenticated;

  /// Completes once the session check has finished (either way).
  final Future<void> Function() sessionSettled;

  /// Shows the session from the cached identity; false when there is none.
  final Future<bool> Function() enterProvisional;

  /// Home catalog fetched. Never throws: a failed fetch counts as done, the
  /// home screen shows its own error / offline state.
  final Future<void> Function() catalogReady;

  /// First route covers warmed. Never throws.
  final Future<void> Function() coversReady;
}

class StartupResult {
  const StartupResult({required this.authenticated, required this.provisional});

  /// Where the person belongs: the home screen (true) or the welcome screen.
  final bool authenticated;

  /// Home opens from the cached identity; the session check is still running.
  final bool provisional;
}

/// Runs the start-up sequence and reports how far along it is. [onMilestone]
/// gets 0..1 (drives the sunrise), [onSlowHint] turns the «checking the
/// connection» caption on and off.
///
/// The whole thing stays within [StartupTiming.ceiling], except when the
/// session is unknown and nothing is cached: then it waits up to
/// [StartupTiming.noCacheCeiling], because there is nothing to open yet.
Future<StartupResult> runStartup({
  required StartupDeps deps,
  required StartupTiming timing,
  required void Function(double milestone) onMilestone,
  required void Function(bool visible) onSlowHint,
}) async {
  // Timers are cancelled on the way out: a finished start-up leaves nothing
  // pending behind it.
  final timers = <Timer>[];
  Future<bool> after(Duration duration) {
    final done = Completer<bool>();
    timers.add(Timer(duration, () => done.complete(false)));
    return done.future;
  }

  try {
    final ceiling = after(timing.ceiling);
    onMilestone(0.3);

    if (!deps.isHydrated()) {
      final settled = await Future.any<bool>([
        deps.sessionSettled().then((_) => true),
        ceiling,
      ]);
      if (!settled) {
        if (await deps.enterProvisional()) {
          onMilestone(1);
          return const StartupResult(authenticated: true, provisional: true);
        }
        onSlowHint(true);
        await Future.any<bool>([
          deps.sessionSettled().then((_) => true),
          after(timing.noCacheCeiling - timing.ceiling),
        ]);
        onSlowHint(false);
      }
    }

    onMilestone(0.55);
    if (!deps.isAuthenticated()) {
      onMilestone(1);
      return const StartupResult(authenticated: false, provisional: false);
    }

    final warm = () async {
      await deps.catalogReady();
      onMilestone(0.8);
      await Future.any<Object?>([
        deps.coversReady(),
        after(timing.coversLimit),
      ]);
    }();
    await Future.any<Object?>([warm, ceiling]);
    onMilestone(1);
    return const StartupResult(authenticated: true, provisional: false);
  } finally {
    for (final timer in timers) {
      timer.cancel();
    }
  }
}
