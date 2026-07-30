import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
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

  /// Resolves a media reference to an image URL, or `null` when it cannot be
  /// trusted.
  ///
  /// Server data is untrusted: only plain relative paths and `http(s)` URLs are
  /// accepted, so schemes such as `javascript:`, `file:` or `data:` never reach
  /// the image pipeline.
  static String? resolveMediaUrl(AppConfig config, String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) {
      return null;
    }
    if (isAssetPath(pathOrUrl)) {
      return null;
    }
    final parsed = Uri.tryParse(pathOrUrl);
    if (parsed == null) {
      return null;
    }
    if (parsed.hasScheme) {
      if (!parsed.isScheme('http') && !parsed.isScheme('https')) {
        return null;
      }
      if (config.environment == AppEnvironment.local) {
        return pathOrUrl;
      }
      final apiOrigin = Uri.parse(config.apiBaseUrl);
      return parsed.isScheme('https') &&
              parsed.host == apiOrigin.host &&
              parsed.port == apiOrigin.port
          ? pathOrUrl
          : null;
    }
    final base = config.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    final path = pathOrUrl.startsWith('/') ? pathOrUrl : '/$pathOrUrl';
    return '$base$path';
  }

  static String routeFallbackAsset(String seed) {
    final index = seed.hashCode.abs() % routeFallbacks.length;
    return routeFallbacks[index];
  }

  /// Avatar/cover [ImageProvider] from a resolved https URL, local `file://`,
  /// or the bundled asset fallback. Network URLs use memory+disk cache.
  static ImageProvider imageProvider({
    required String? resolvedUrl,
    String assetFallback = travelerPortrait,
  }) {
    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      if (resolvedUrl.startsWith('file://')) {
        return FileImage(File(Uri.parse(resolvedUrl).toFilePath()));
      }
      return CachedNetworkImageProvider(resolvedUrl);
    }
    return AssetImage(assetFallback);
  }

  /// Resolves session/API avatar refs (including local `file://` previews).
  static ImageProvider avatarProvider({
    required AppConfig config,
    required String? avatarUrl,
    String assetFallback = travelerPortrait,
  }) {
    if (avatarUrl != null && avatarUrl.startsWith('file://')) {
      return FileImage(File(Uri.parse(avatarUrl).toFilePath()));
    }
    return imageProvider(
      resolvedUrl: resolveMediaUrl(config, avatarUrl),
      assetFallback: assetFallback,
    );
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
      return CachedNetworkImage(
        imageUrl: networkUrl,
        fit: fit,
        alignment: alignment is Alignment ? alignment : Alignment.center,
        errorWidget: (_, _, _) =>
            Image.asset(fallback, fit: fit, alignment: alignment),
        placeholder: (_, _) =>
            Image.asset(fallback, fit: fit, alignment: alignment),
      );
    }
    return Image.asset(fallback, fit: fit, alignment: alignment);
  }
}
