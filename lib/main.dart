import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/core/notifications/app_push.dart';
import 'package:tourism_mobile/core/performance/app_perf.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  AppPerf.configureImageCache();
  if (AppPush.isConfigured) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(
    LiquidGlassWidgets.wrap(
      // MaterialApp.router uses a fixed AppTheme.light regardless of system
      // brightness (see app.dart) — without this, glass widgets would read
      // the raw OS brightness instead and could pick dark-mode tinting even
      // though the app itself never renders a dark theme.
      brightnessResolver: Theme.maybeBrightnessOf,
      child: const ProviderScope(child: TourismApp()),
    ),
  );
  if (AppPush.isConfigured) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AppPush.bootstrap());
    });
  }
}
