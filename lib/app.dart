import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/cache/stale_data_refresher.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/core/notifications/app_push.dart';
import 'package:tourism_mobile/core/notifications/push_sync.dart';
import 'package:tourism_mobile/core/startup/startup_config.dart';
import 'package:tourism_mobile/core/startup/startup_gate.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/route_publish/application/route_draft_providers.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/settings/application/liquid_glass_preference.dart';
import 'package:tourism_mobile/features/settings/application/motion_preference.dart';
import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class TourismApp extends ConsumerStatefulWidget {
  const TourismApp({super.key});

  @override
  ConsumerState<TourismApp> createState() => _TourismAppState();
}

class _TourismAppState extends ConsumerState<TourismApp> {
  /// A notification tapped while the preloader is still up; opened right
  /// after it closes (and dropped for a guest).
  RemoteMessage? _pendingPush;

  @override
  void initState() {
    super.initState();
    if (AppPush.isConfigured) {
      AppPush.onOpened = (message) {
        if (ref.read(startupGateActiveProvider)) {
          _pendingPush = message;
          return;
        }
        final router = ref.read(appRouterProvider);
        handlePushOpened(router, message);
      };
      AppPush.onForeground = (_) {
        unawaited(ref.read(notificationsInboxProvider.notifier).softRefresh());
      };
    }
  }

  Future<void> _resumeRouteDrafts(SessionState session) async {
    final drafts = ref.read(routeDraftSyncServiceProvider);
    await drafts.finishInterruptedSignOut();
    final userId = session.userId;
    if (session.isAuthenticated && userId != null && userId.isNotEmpty) {
      await drafts.syncPending(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final router = ref.watch(appRouterProvider);
    ref.watch(appHapticsEnabledProvider);
    // «Жидкое стекло» из настроек — читается напрямую через AppGlassSettings
    // в build() кнопок (не Consumer), поэтому нужен watch здесь же, чтобы
    // смена флага перестраивала дерево целиком: тот же приём, что и выше.
    ref.watch(liquidGlassEnabledProvider);
    // Warm primary catalogs during bootstrap so tab switches / search do not
    // hitch on cold network+decode. Home later reuses the same cached futures.
    ref
      ..watch(homeRoutesProvider)
      ..watch(routesListProvider)
      ..watch(placesListProvider)
      ..watch(topTravelersProvider);

    ref.listen<bool>(startupGateActiveProvider, (previous, active) {
      final message = _pendingPush;
      if (active || message == null) {
        return;
      }
      _pendingPush = null;
      if (ref.read(sessionProvider).isAuthenticated) {
        handlePushOpened(ref.read(appRouterProvider), message);
      }
    });

    // Register FCM token whenever an authenticated session has push enabled
    // (cold start / login), not only when the settings toggle flips.
    ref.listen<SessionState>(sessionProvider, (previous, next) {
      // A route draft left unsent by the last run (killed, or no network) is
      // sent now; an interrupted sign-out is finished first.
      if (next.isHydrated &&
          (previous == null ||
              !previous.isHydrated ||
              previous.userId != next.userId)) {
        unawaited(_resumeRouteDrafts(next));
      }
      final becameReady =
          next.isAuthenticated &&
          next.notifyPushEnabled &&
          (previous == null ||
              !previous.isAuthenticated ||
              !previous.notifyPushEnabled ||
              previous.userId != next.userId);
      if (becameReady) {
        ensurePushRegistrationForSession(ref, next);
      }
    });

    // Обёртка вокруг всего приложения: вернувшись из фона спустя долгое
    // время, человек должен увидеть свежие данные, а не то, что оставил.
    // «Меньше анимаций» из настроек: длительности AppMotion уже нулевые, а
    // этот флаг гасит то, что рисует фреймворк и чужие виджеты — например
    // бесконечное мерцание скелетонов.
    final reduceMotion = ref.watch(reduceMotionProvider);

    return StaleDataRefresher(
      child: MaterialApp.router(
        title: config.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) {
          final content = child ?? const SizedBox.shrink();
          return StartupGate(
            child: reduceMotion
                ? MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: true),
                    child: content,
                  )
                : content,
          );
        },
      ),
    );
  }
}
