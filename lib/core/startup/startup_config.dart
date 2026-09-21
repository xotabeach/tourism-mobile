import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Turns the start-up gate (the preloader) off. Tests do this so their many
/// `pumpAndSettle` calls do not wait on the gate's timers.
final Provider<bool> startupGateEnabledProvider = Provider<bool>((ref) => true);

/// Every start-up duration in one place so tests can shrink them.
class StartupTiming {
  const StartupTiming({
    this.minimum = const Duration(milliseconds: 1500),
    this.ceiling = const Duration(seconds: 4),
    this.noCacheCeiling = const Duration(seconds: 10),
    this.coversLimit = const Duration(seconds: 1),
    this.fade = const Duration(milliseconds: 350),
    this.routerSettle = const Duration(seconds: 1),
  });

  /// Shortest time the animation plays, so a fast start does not flicker.
  final Duration minimum;

  /// Longest the gate waits for the session and the first screen's data.
  final Duration ceiling;

  /// Longest it waits when the session is still unknown and there is no cached
  /// identity to show meanwhile.
  final Duration noCacheCeiling;

  /// Extra budget for warming the first route covers once the catalog is in.
  final Duration coversLimit;

  /// Cross-fade from the gate to the screen underneath.
  final Duration fade;

  /// Safety net: close anyway if the router never reaches the target screen.
  final Duration routerSettle;
}

final Provider<StartupTiming> startupTimingProvider = Provider<StartupTiming>(
  (ref) => const StartupTiming(),
);

/// True until the gate has finished, once per process: coming back from the
/// background or rebuilding the app widget never shows it again.
final StateProvider<bool> startupGateOpenProvider = StateProvider<bool>(
  (ref) => true,
);

/// The gate is up right now (enabled and not yet finished).
final Provider<bool> startupGateActiveProvider = Provider<bool>(
  (ref) =>
      ref.watch(startupGateEnabledProvider) &&
      ref.watch(startupGateOpenProvider),
);
