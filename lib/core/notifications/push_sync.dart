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

var _tokenRefreshBound = false;

/// Sync FCM token with backend when the user enables push (and Firebase is configured).
///
/// Returns `true` when push is considered active after the call (token registered
/// on enable, or successfully disabled). Returns `false` when enable failed
/// (typically OS permission denied).
Future<bool> syncPushRegistration(
  WidgetRef ref, {
  required bool enabled,
}) async {
  if (!AppPush.isConfigured || kIsWeb) {
    return enabled;
  }
  if (!AppPush.isReady) {
    // Firebase not bootstrapped yet (widget tests / early frame).
    return false;
  }
  final session = ref.read(sessionProvider);
  if (!session.isAuthenticated) {
    return false;
  }
  final repo = ref.read(deviceTokenRepositoryProvider);
  final platform = Platform.isIOS ? 'ios' : 'android';
  if (!enabled) {
    try {
      final existing = await FirebaseMessaging.instance.getToken();
      if (existing != null && existing.isNotEmpty) {
        await repo.unregister(existing);
      }
    } on Object {
      // Best-effort cleanup; local preference already flipped off.
    }
    await AppPush.disableAutoInit();
    return true;
  }
  final token = await AppPush.enableAndGetToken();
  if (token == null || token.isEmpty) {
    return false;
  }
  await repo.register(token: token, platform: platform);
  if (!_tokenRefreshBound) {
    _tokenRefreshBound = true;
    AppPush.onTokenRefresh.listen((next) {
      unawaited(repo.register(token: next, platform: platform));
    });
  }
  return true;
}

/// Call after session hydrate / login when push prefs are already on.
///
/// Token registration used to run only on the settings toggle, so users with
/// the default «push on» never posted a device token after Firebase landed.
void ensurePushRegistrationForSession(WidgetRef ref, SessionState session) {
  if (!AppPush.isReady || kIsWeb) {
    return;
  }
  if (!session.isAuthenticated || !session.notifyPushEnabled) {
    return;
  }
  unawaited(syncPushRegistration(ref, enabled: true));
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
    return;
  }
  if (targetType == 'user' && targetId is String && targetId.isNotEmpty) {
    unawaited(
      router.pushNamed(
        AppRouteNames.userProfile,
        pathParameters: {'userId': targetId},
      ),
    );
    return;
  }
  if (targetType == 'achievement') {
    unawaited(router.pushNamed(AppRouteNames.achievements));
  }
}
