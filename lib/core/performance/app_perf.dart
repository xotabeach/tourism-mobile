import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';

/// Runtime performance knobs for mid-range phones (e.g. Redmi Note 12 Pro).
///
/// Backdrop blurs and long shell morphs are the main jank sources on Mali-class
/// Android GPUs; iOS keeps the richer glass/motion treatment.
abstract final class AppPerf {
  static bool get preferCheapEffects =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Soften glass blur on Android; keep the requested sigma elsewhere.
  static double glassBlur(double desired) {
    if (desired <= 0) return 0;
    return preferCheapEffects ? 0 : desired;
  }

  /// Without live blur, frosted translucent fills read as washed-out discs and
  /// clash with white glyphs. Match the solid «Пройти маршрут» / nav chrome.
  /// Zero alpha stays transparent so fade-out animations can still hide chrome.
  static Color glassFill(Color requested) {
    if (!preferCheapEffects) return requested;
    if (requested.a <= 0) {
      return AppColors.activeNavigationFill.withValues(alpha: 0);
    }
    return AppColors.activeNavigationFill;
  }

  static Color glassBorder(Color requested) {
    if (!preferCheapEffects) return requested;
    if (requested.a <= 0) {
      return Colors.white.withValues(alpha: 0);
    }
    return Colors.white.withValues(alpha: 0.22);
  }

  /// Icon / label color for glass controls that fall back to [glassFill].
  static Color glassForeground(Color requested) {
    if (!preferCheapEffects) return requested;
    return Colors.white;
  }

  /// Scale motion durations down on Android without killing the feel entirely.
  static Duration motion(Duration desired) {
    if (!preferCheapEffects) return desired;
    final ms = desired.inMilliseconds;
    if (ms <= 0) return desired;
    return Duration(milliseconds: (ms * 0.72).round().clamp(80, ms));
  }

  static void configureImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    // Keep more decoded covers warm across tab switches; still bounded for
    // 6–8 GB mid-range devices.
    cache.maximumSize = preferCheapEffects ? 120 : 160;
    cache.maximumSizeBytes = preferCheapEffects ? 120 << 20 : 160 << 20;
  }
}
