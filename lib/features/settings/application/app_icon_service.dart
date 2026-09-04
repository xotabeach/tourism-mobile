import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Alternate launcher icons, a Travel+ perk.
///
/// Both platforms require every icon to be baked into the build — Android
/// reads them from the manifest at install time, iOS from Info.plist — so
/// the list here is fixed at release, not fetched.
enum AppIconVariant {
  standard('default', 'Стандартная'),
  sunset('sunset', 'Закат'),
  sea('sea', 'Море'),
  night('night', 'Ночь');

  const AppIconVariant(this.id, this.label);

  final String id;
  final String label;

  String get previewAsset => 'assets/icons/app/$id.png';

  static AppIconVariant fromId(String? id) {
    return AppIconVariant.values.firstWhere(
      (variant) => variant.id == id,
      orElse: () => AppIconVariant.standard,
    );
  }
}

class AppIconService {
  const AppIconService(this._channel);

  final MethodChannel _channel;

  /// Which icon is live right now, asked of the platform rather than stored:
  /// the launcher is the source of truth, and a value cached in the app would
  /// drift after a reinstall.
  Future<AppIconVariant> current() async {
    try {
      final id = await _channel.invokeMethod<String>('currentAppIcon');
      return AppIconVariant.fromId(id);
    } on PlatformException {
      return AppIconVariant.standard;
    } on MissingPluginException {
      return AppIconVariant.standard;
    }
  }

  /// Returns null on success, or a message to show the user.
  Future<String?> apply(AppIconVariant variant) async {
    try {
      await _channel.invokeMethod<void>('setAppIcon', {'variant': variant.id});
      return null;
    } on PlatformException catch (error) {
      return error.message ?? 'Не удалось сменить иконку';
    } on MissingPluginException {
      return 'Смена иконки недоступна на этом устройстве';
    }
  }
}

final appIconServiceProvider = Provider<AppIconService>((ref) {
  return const AppIconService(
    MethodChannel('com.crimeatravel.tourism_mobile/settings'),
  );
});

final currentAppIconProvider = FutureProvider<AppIconVariant>((ref) {
  return ref.watch(appIconServiceProvider).current();
});
