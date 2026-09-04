import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';

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
  static const String click = '$_root/click.png';

  // Settings — section roots
  static const String settingsProfile = '$_root/settings_profile.png';
  static const String settingsNotifications =
      '$_root/settings_notifications.png';
  static const String settingsOffline = '$_root/settings_offline.png';
  static const String settingsSupport = '$_root/settings_support.png';
  static const String settingsAbout = '$_root/settings_about.png';

  // Settings — profile
  static const String settingsChangeName = '$_root/settings_change_name.png';
  static const String settingsChangePhoto = '$_root/settings_change_photo.png';
  static const String settingsChangePhone = '$_root/settings_change_phone.png';
  static const String settingsChangePreferences =
      '$_root/settings_change_preferences.png';
  static const String settingsChat = '$_root/settings_chat.png';

  /// История чатов с ИИ — иконка от дизайнера (chat_story.svg, 2026-09-04).
  static const String settingsChatHistory =
      '$_root/settings_chat_history.png';

  // Settings — notifications
  static const String settingsPush = '$_root/settings_push.png';
  static const String settingsSms = '$_root/settings_sms.png';
  static const String settingsVibro = '$_root/settings_vibro.png';

  // Settings — offline
  static const String settingsAutoDownload =
      '$_root/settings_auto_download.png';
  static const String settingsAskDownload = '$_root/settings_ask_download.png';

  // Settings — support / FAQ
  static const String settingsFaqRoutes = '$_root/settings_faq_routes.png';
  static const String settingsFaqApp = '$_root/settings_faq_app.png';
  static const String settingsTravelPoints =
      '$_root/settings_travel_points.png';
  static const String settingsTravelPlus = '$_root/settings_travel_plus.png';
  static const String settingsReport = '$_root/settings_report.png';
  static const String settingsRate = '$_root/settings_rate.png';

  static const List<String> settingsAssets = [
    settingsProfile,
    settingsNotifications,
    settingsOffline,
    settingsSupport,
    settingsAbout,
    settingsChangeName,
    settingsChangePhoto,
    settingsChangePhone,
    settingsChangePreferences,
    settingsChat,
    settingsPush,
    settingsSms,
    settingsVibro,
    settingsAutoDownload,
    settingsAskDownload,
    settingsFaqRoutes,
    settingsFaqApp,
    settingsTravelPoints,
    settingsTravelPlus,
    settingsReport,
    settingsRate,
  ];

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
    click,
    ...settingsAssets,
  ];

  static String inkAsset(String asset) {
    return asset.replaceFirst('/raster/', '/raster/ink/');
  }

  static String mutedAsset(String asset) {
    return asset.replaceFirst('/raster/', '/raster/muted/');
  }

  static String accentAsset(String asset) {
    return asset.replaceFirst('/raster/', '/raster/accent/');
  }

  static String profileAsset(String asset) {
    return asset.replaceFirst('/raster/', '/raster/profile/');
  }

  static List<String> get bundledAssets => [
    ...runtimeAssets,
    ...runtimeAssets.map(inkAsset),
    ...runtimeAssets.map(mutedAsset),
    ...runtimeAssets.map(profileAsset),
    ...settingsAssets.map(accentAsset),
  ];

  static const double navigation = 28;
  static const double action = 24;
  static const double metadata = 18;
  static const double settings = 28;

  /// True when [color] is the settings accent blue (not gray/black/white).
  static bool isAccentBlue(Color color) {
    const target = AppColors.accentBlueIcon;
    final dr = (color.r - target.r).abs();
    final dg = (color.g - target.g).abs();
    final db = (color.b - target.b).abs();
    return dr + dg + db < 0.35;
  }

  static bool isProfileStatColor(Color color) {
    const target = AppColors.profileStatIcon;
    final dr = (color.r - target.r).abs();
    final dg = (color.g - target.g).abs();
    final db = (color.b - target.b).abs();
    return dr + dg + db < 0.08;
  }
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
    final String effectiveAsset;
    if (AppIconography.isProfileStatColor(iconColor)) {
      effectiveAsset = AppIconography.profileAsset(asset);
    } else if (channelAverage < 0.3) {
      effectiveAsset = AppIconography.inkAsset(asset);
    } else if (AppIconography.isAccentBlue(iconColor)) {
      effectiveAsset = AppIconography.accentAsset(asset);
    } else if (channelAverage < 0.8) {
      effectiveAsset = AppIconography.mutedAsset(asset);
    } else {
      effectiveAsset = asset;
    }
    final image = Image.asset(
      effectiveAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      errorBuilder: (_, _, _) {
        // Older icons may lack an accent export — fall back to muted.
        return Image.asset(
          AppIconography.mutedAsset(asset),
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        );
      },
    );

    return iconColor.a < 1
        ? Opacity(opacity: iconColor.a, child: image)
        : image;
  }
}
