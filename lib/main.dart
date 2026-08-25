import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/core/notifications/app_push.dart';
import 'package:tourism_mobile/core/performance/app_perf.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppPerf.configureImageCache();
  if (AppPush.isConfigured) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(const ProviderScope(child: TourismApp()));
  if (AppPush.isConfigured) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AppPush.bootstrap());
    });
  }
}
