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

  /// White / near-white glyphs that need solid dark chrome without live blur.
  static bool isLightGlyph(Color color) {
    if (color.a < 0.08) return false;
    return color.computeLuminance() >= 0.72;
  }

  /// Whether Android should replace a frosted fill with solid nav chrome.
  ///
  /// Only for controls whose icon/label is white (or near-white). Dark glyphs
  /// keep the original light fill — blur is still disabled via [glassBlur].
  static bool useDarkGlassChrome({Color? contentColor}) {
    if (!preferCheapEffects) return false;
    if (contentColor == null) return false;
    return isLightGlyph(contentColor);
  }

  /// Without live blur, pale frosted discs clash with white glyphs. Match the
  /// solid «Пройти маршрут» / nav chrome **only** when [foreground] is light.
  /// Zero alpha stays transparent so fade-out animations can still hide chrome.
  static Color glassFill(Color requested, {Color? foreground}) {
    if (!useDarkGlassChrome(contentColor: foreground)) return requested;
    if (requested.a <= 0) {
      return AppColors.activeNavigationFill.withValues(alpha: 0);
    }
    return AppColors.activeNavigationFill;
  }

  static Color glassBorder(Color requested, {Color? foreground}) {
    if (!useDarkGlassChrome(contentColor: foreground)) return requested;
    if (requested.a <= 0) {
      return Colors.white.withValues(alpha: 0);
    }
    return Colors.white.withValues(alpha: 0.22);
  }

  /// Scale motion durations down on Android without killing the feel entirely.
  ///
  /// The 80 ms floor only applies to tokens that are already longer than it —
  /// a token below the floor (e.g. the 70 ms nav tint) is left alone rather
  /// than clamped upwards, which would otherwise invert the clamp bounds.
  static Duration motion(Duration desired) {
    if (!preferCheapEffects) return desired;
    final ms = desired.inMilliseconds;
    if (ms <= 0) return desired;
    final floor = ms < 80 ? ms : 80;
    return Duration(milliseconds: (ms * 0.72).round().clamp(floor, ms));
  }

  static void configureImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    // Keep more decoded covers warm across tab switches; still bounded for
    // 6–8 GB mid-range devices.
    cache.maximumSize = preferCheapEffects ? 120 : 160;
    cache.maximumSizeBytes = preferCheapEffects ? 120 << 20 : 160 << 20;
  }
}
