import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// "App version (build). Device, OS version." label for bug-report screens —
/// read from the platform instead of typed by hand, so it can never drift
/// from what's actually installed and running.
Future<String> resolveDeviceAndVersionLabel() async {
  final packageInfo = await PackageInfo.fromPlatform();
  final versionLabel =
      'Версия ${packageInfo.version} (${packageInfo.buildNumber})';

  final deviceLabel = await _deviceLabel();
  return '$versionLabel. $deviceLabel.';
}

Future<String> _deviceLabel() async {
  final deviceInfo = DeviceInfoPlugin();
  try {
    if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      return '${ios.utsname.machine}, iOS ${ios.systemVersion}';
    }
    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      return '${android.manufacturer} ${android.model}, '
          'Android ${android.version.release}';
    }
  } on Object {
    // Fall through to the generic label below.
  }
  return Platform.operatingSystem;
}

final deviceAndVersionLabelProvider = FutureProvider<String>((ref) {
  return resolveDeviceAndVersionLabel();
});
