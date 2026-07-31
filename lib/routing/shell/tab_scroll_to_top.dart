import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incremented when the user re-taps an already-selected shell tab at its root.
/// Tab screens listen and scroll their primary list to the top.
final tabScrollToTopProvider = StateProvider.family<int, int>((ref, tabIndex) {
  return 0;
});
