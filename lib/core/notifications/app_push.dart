import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:tourism_mobile/firebase_options.dart';

/// FCM bootstrap. Safe no-op until [DefaultFirebaseOptions.configured] is true
/// (after `flutterfire configure` + platform config files).
abstract final class AppPush {
  static bool get isConfigured => DefaultFirebaseOptions.configured;

  static bool _started = false;
  static void Function(RemoteMessage message)? onOpened;

  static Future<void> bootstrap({
    void Function(RemoteMessage message)? onMessageOpened,
  }) async {
    if (_started || !isConfigured || kIsWeb) {
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    _started = true;
    onOpened = onMessageOpened;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Respect product toggle / OS permission; do not auto-spam the prompt.
    await FirebaseMessaging.instance.setAutoInitEnabled(false);

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onOpened?.call(message);
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      onOpened?.call(initial);
    }
  }

  /// Ask OS permission (iOS / Android 13+) and return the FCM token when ready.
  static Future<String?> enableAndGetToken() async {
    if (!isConfigured) {
      return null;
    }
    await FirebaseMessaging.instance.setAutoInitEnabled(true);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }

    if (Platform.isIOS) {
      // APNs token must exist before getToken on Apple platforms.
      for (var i = 0; i < 10; i++) {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }

    return FirebaseMessaging.instance.getToken();
  }

  static Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  static Future<void> disableAutoInit() async {
    if (!isConfigured) {
      return;
    }
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
  }
}

/// Background isolate handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!DefaultFirebaseOptions.configured) {
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
