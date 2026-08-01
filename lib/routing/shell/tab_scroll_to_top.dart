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

const double kTabScrolledDownThreshold = 48;

void syncTabScrolledDown(WidgetRef ref, int tabIndex, double offset) {
  final down = offset > kTabScrolledDownThreshold;
  final notifier = ref.read(tabScrolledDownProvider(tabIndex).notifier);
  if (notifier.state != down) {
    notifier.state = down;
  }
}
