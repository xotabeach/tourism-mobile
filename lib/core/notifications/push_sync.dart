import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/notifications/app_push.dart';
import 'package:tourism_mobile/core/notifications/device_token_repository.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Sync FCM token with backend when the user enables push (and Firebase is configured).
Future<void> syncPushRegistration(WidgetRef ref, {required bool enabled}) async {
  if (!AppPush.isConfigured || kIsWeb) {
    return;
  }
  final session = ref.read(sessionProvider);
  if (!session.isAuthenticated) {
    return;
  }
  final repo = ref.read(deviceTokenRepositoryProvider);
  if (!enabled) {
    await AppPush.disableAutoInit();
    return;
  }
  final token = await AppPush.enableAndGetToken();
  if (token == null || token.isEmpty) {
    return;
  }
  final platform = Platform.isIOS ? 'ios' : 'android';
  await repo.register(token: token, platform: platform);
  AppPush.onTokenRefresh.listen((next) {
    unawaited(repo.register(token: next, platform: platform));
  });
}

void handlePushOpened(GoRouter router, RemoteMessage message) {
  final data = message.data;
  final targetType = data['target_type'];
  final targetId = data['target_id'];
  if (targetType == 'route' && targetId is String && targetId.isNotEmpty) {
    unawaited(
      router.pushNamed(
        AppRouteNames.routeDetails,
        pathParameters: {'id': targetId},
      ),
    );
  }
}
