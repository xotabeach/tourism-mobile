import 'package:flutter/material.dart';

abstract final class AppIconography {
  static const String _root = 'assets/icons/raster';

  static const String arrow = '$_root/arrow.png';
  static const String bell = '$_root/bell.png';
  static const String download = '$_root/download.png';
  static const String filter = '$_root/filter.png';
  static const String heart = '$_root/heart.png';
  static const String home = '$_root/home.png';
  static const String map = '$_root/map.png';
  static const String menu = '$_root/menu.png';
  static const String phone = '$_root/phone.png';
  static const String play = '$_root/play.png';
  static const String build = '$_root/plus.png';
  static const String profile = '$_root/profile_outline.png';
  static const String profileSelected = '$_root/profile_filled.png';
  static const String routes = '$_root/routes.png';
  static const String search = '$_root/search.png';
  static const String sendToEnd = '$_root/send_to_end.png';
  static const String variant17 = '$_root/variant_17.png';

  static const List<String> runtimeAssets = [
    arrow,
    bell,
    download,
    filter,
    heart,
    home,
    map,
    menu,
    phone,
    play,
    build,
    profileSelected,
    profile,
    routes,
    search,
    sendToEnd,
    variant17,
  ];

  static String inkAsset(String asset) {
    return asset.replaceFirst('/raster/', '/raster/ink/');
  }

  static String mutedAsset(String asset) {
    return asset.replaceFirst('/raster/', '/raster/muted/');
  }

  static List<String> get bundledAssets => [
    ...runtimeAssets,
    ...runtimeAssets.map(inkAsset),
    ...runtimeAssets.map(mutedAsset),
  ];

  static const double navigation = 28;
  static const double action = 24;
  static const double metadata = 18;
}

class AppAssetIcon extends StatelessWidget {
  const AppAssetIcon(
    this.asset, {
    this.size = AppIconography.action,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final String asset;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Colors.white;
    final channelAverage = (iconColor.r + iconColor.g + iconColor.b) / 3;
    final effectiveAsset = channelAverage < 0.3
        ? AppIconography.inkAsset(asset)
        : channelAverage < 0.8
        ? AppIconography.mutedAsset(asset)
        : asset;
    final image = Image.asset(
      effectiveAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );

    return iconColor.a < 1
        ? Opacity(opacity: iconColor.a, child: image)
        : image;
  }
}
