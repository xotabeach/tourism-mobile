import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/config/app_config.dart';

/// Bundled design photos (Figma export) + helpers for API `/media` URLs.
abstract final class AppImages {
  static const welcomeSunset = 'assets/images/welcome-sunset.jpg';
  static const coastPineTwilight = 'assets/images/coast-pine-twilight.jpg';
  static const capeFiolentFog = 'assets/images/cape-fiolent-fog.jpg';
  static const coastalBayHills = 'assets/images/coastal-bay-hills.jpg';
  static const travelerPortrait = 'assets/images/traveler-portrait-bw.jpg';

  static const routeFallbacks = [
    coastPineTwilight,
    capeFiolentFog,
    coastalBayHills,
    welcomeSunset,
  ];

  static bool isAssetPath(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) {
      return false;
    }
    return pathOrUrl.startsWith('assets/');
  }

  static String? resolveMediaUrl(AppConfig config, String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) {
      return null;
    }
    if (isAssetPath(pathOrUrl)) {
      return null;
    }
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    final base = config.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    final path = pathOrUrl.startsWith('/') ? pathOrUrl : '/$pathOrUrl';
    return '$base$path';
  }

  static String routeFallbackAsset(String seed) {
    final index = seed.hashCode.abs() % routeFallbacks.length;
    return routeFallbacks[index];
  }

  /// Stable mock/local cover for place catalog and detail heroes.
  static String placeCoverAsset(String slug) {
    return switch (slug) {
      'swallow-nest' || 'livadia-palace' => welcomeSunset,
      'ai-petri' || 'chufut-kale' => coastPineTwilight,
      'cape-fiolent' || 'novy-svet' => capeFiolentFog,
      _ => coastalBayHills,
    };
  }

  /// Cover for mock (asset path) or API media; falls back to [routeFallbackAsset].
  static Widget coverImage({
    required AppConfig config,
    required String? coverImageUrl,
    required String fallbackSeed,
    BoxFit fit = BoxFit.cover,
    AlignmentGeometry alignment = Alignment.center,
  }) {
    final fallback = routeFallbackAsset(fallbackSeed);
    if (isAssetPath(coverImageUrl)) {
      return Image.asset(coverImageUrl!, fit: fit, alignment: alignment);
    }
    final networkUrl = resolveMediaUrl(config, coverImageUrl);
    if (networkUrl != null) {
      return Image.network(
        networkUrl,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, _, _) =>
            Image.asset(fallback, fit: fit, alignment: alignment),
      );
    }
    return Image.asset(fallback, fit: fit, alignment: alignment);
  }
}
