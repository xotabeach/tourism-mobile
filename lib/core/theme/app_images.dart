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

  static String? resolveMediaUrl(AppConfig config, String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) {
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
}
