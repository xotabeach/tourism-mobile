import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When true, shell hides the floating nav (AI chat composer owns the bottom).
final routeMatchAiModeProvider = StateProvider<bool>((ref) => false);
