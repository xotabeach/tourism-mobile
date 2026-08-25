import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:tourism_mobile/core/config/app_config.dart';

/// Bundled design photos (Figma export) + helpers for API `/media` URLs.
abstract final class AppImages {
  /// The package's `DefaultCacheManager` caps disk cache at 200 objects,
  /// which a catalog of 5000+ places plus routes/avatars/review photos
  /// blows past in normal use — older entries get evicted and genuinely
  /// re-downloaded on revisit. This raises the cap; every helper below that
  /// builds a network image provider/widget must pass it explicitly.
  static final cacheManager = CacheManager(
    Config(
      'appImageCache',
      stalePeriod: const Duration(days: 60),
      maxNrOfCacheObjects: 2000,
    ),
  );
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

  static const coverPlaceholderColor = Color(0xFFE7E7E7);

  /// 1×1 gray PNG so [Image] / [DecorationImage] can reserve space without a
  /// bundled photo flash while network covers load or when media is missing.
  static final grayCoverProvider = MemoryImage(
    Uint8List.fromList(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x02,
      0x00,
      0x00,
      0x00,
      0x90,
      0x77,
      0x53,
      0xDE,
      0x00,
      0x00,
      0x00,
      0x0C,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x78,
      0xFE,
      0xFC,
      0x39,
      0x00,
      0x05,
      0x6E,
      0x02,
      0xB6,
      0xC5,
      0xB5,
      0xCE,
      0xBB,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]),
  );

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
      return CachedNetworkImageProvider(resolvedUrl, cacheManager: cacheManager);
    }
    return AssetImage(assetFallback);
  }

  /// A size-bounded route cover provider suitable for preloading. Decoding a
  /// phone-sized card from a multi-megapixel upload wastes memory and causes
  /// visible raster-thread stalls on mid-range Android GPUs.
  static ImageProvider? routeCoverProvider({
    required AppConfig config,
    required String? coverImageUrl,
    required String fallbackSeed,
    required int cacheWidth,
  }) {
    if (isAssetPath(coverImageUrl)) {
      return ResizeImage.resizeIfNeeded(
        cacheWidth,
        null,
        AssetImage(coverImageUrl!),
      );
    }
    final resolved = resolveMediaUrl(config, coverImageUrl);
    if (resolved == null) {
      return null;
    }
    return ResizeImage.resizeIfNeeded(
      cacheWidth,
      null,
      CachedNetworkImageProvider(resolved, cacheManager: cacheManager),
    );
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

  /// Cover for API media. Missing/loading/error frames are a flat gray fill
  /// (no bundled photo flash). Local `assets/` paths still render immediately.
  static Widget coverImage({
    required AppConfig config,
    required String? coverImageUrl,
    required String fallbackSeed,
    BoxFit fit = BoxFit.cover,
    AlignmentGeometry alignment = Alignment.center,
  }) {
    const loadingFill = coverPlaceholderColor;
    if (isAssetPath(coverImageUrl)) {
      return Image.asset(coverImageUrl!, fit: fit, alignment: alignment);
    }
    final networkUrl = resolveMediaUrl(config, coverImageUrl);
    if (networkUrl == null) {
      return const ColoredBox(color: loadingFill);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        // The decode size is part of the image key, so it must NOT track live
        // constraints: inside a collapsing hero the slot shrinks every frame,
        // which re-resolved the provider on each pixel of scroll and dropped
        // the widget back to [placeholder] mid-gesture. Key on width only
        // (height follows from [fit]) and quantise it into coarse buckets so
        // ordinary resizes reuse the same decoded frame.
        const bucket = 256;
        final cacheWidth = constraints.maxWidth.isFinite
            ? (((constraints.maxWidth * pixelRatio) / bucket).ceil() * bucket)
                  .clamp(bucket, 2048)
            : null;

        return CachedNetworkImage(
          imageUrl: networkUrl,
          cacheManager: cacheManager,
          fit: fit,
          alignment: alignment is Alignment ? alignment : Alignment.center,
          memCacheWidth: cacheWidth,
          errorWidget: (_, _, _) => const ColoredBox(color: loadingFill),
          placeholder: (_, _) => const ColoredBox(color: loadingFill),
        );
      },
    );
  }
}
