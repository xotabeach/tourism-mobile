import 'package:flutter/widgets.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';

/// Resolves an article image the same way everywhere it is drawn (card cover,
/// reading-screen cover, image block).
///
/// The three cases differ and getting one wrong is silent: a bundled
/// `assets/...` path (what `DATA_SOURCE=mock` serves) must become an
/// `AssetImage` rather than being run through `resolveMediaUrl`, which returns
/// null for it and would quietly fall back to the stock portrait.
ImageProvider articleImageProvider({
  required AppConfig config,
  required String? url,
  required String fallbackSeed,
}) {
  if (url != null && AppImages.isAssetPath(url)) {
    return AssetImage(url);
  }
  return AppImages.imageProvider(
    resolvedUrl: AppImages.resolveMediaUrl(config, url),
    assetFallback: AppImages.routeFallbackAsset(fallbackSeed),
  );
}
