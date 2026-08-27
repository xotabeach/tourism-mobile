import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incremented when the user re-taps an already-selected shell tab at its root.
/// Tab screens listen and scroll their primary list to the top.
final tabScrollToTopProvider = StateProvider.family<int, int>((ref, tabIndex) {
  return 0;
});

/// True when the tab's primary scroll view is past [kTabScrolledDownThreshold].
final tabScrolledDownProvider = StateProvider.family<bool, int>((
  ref,
  tabIndex,
) {
  return false;
});

/// True while the tab's floating nav should sit collapsed on its compact
/// droplet.
///
/// Unlike [tabScrolledDownProvider] this follows scroll *direction*, not
/// absolute offset: the bar folds away as the user reads downwards and comes
/// back the moment they scroll up, anywhere in the list. Keying it to offset
/// instead would leave the bar collapsed until the list was scrolled all the
/// way back to the top.
final tabNavCollapsedProvider = StateProvider.family<bool, int>((
  ref,
  tabIndex,
) {
  return false;
});

/// Last offset [syncTabScrolledDown] acted on, per tab — a provider rather
/// than module state so each [ProviderContainer] (and so each test) starts
/// clean.
final _tabScrollOffsetProvider = StateProvider.family<double, int>((
  ref,
  tabIndex,
) {
  return 0;
});

const double kTabScrolledDownThreshold = 48;

/// How far the user has to move before a direction change counts. Below this
/// a list that is merely settling — or a finger resting on it — would flap the
/// nav open and shut.
const double kNavCollapseDelta = 14;

void syncTabScrolledDown(WidgetRef ref, int tabIndex, double offset) {
  final down = offset > kTabScrolledDownThreshold;
  final notifier = ref.read(tabScrolledDownProvider(tabIndex).notifier);
  if (notifier.state != down) {
    notifier.state = down;
  }

  final lastOffset = ref.read(_tabScrollOffsetProvider(tabIndex).notifier);
  final delta = offset - lastOffset.state;
  if (delta.abs() < kNavCollapseDelta) {
    return;
  }
  lastOffset.state = offset;
  // Never collapsed near the top: the bar should be whole whenever the list is.
  final collapsed = delta > 0 && down;
  final collapsedNotifier = ref.read(
    tabNavCollapsedProvider(tabIndex).notifier,
  );
  if (collapsedNotifier.state != collapsed) {
    collapsedNotifier.state = collapsed;
  }
}
