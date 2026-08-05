import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/core/notifications/app_push.dart';
import 'package:tourism_mobile/core/notifications/push_sync.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class TourismApp extends ConsumerStatefulWidget {
  const TourismApp({super.key});

  @override
  ConsumerState<TourismApp> createState() => _TourismAppState();
}

class _TourismAppState extends ConsumerState<TourismApp> {
  @override
  void initState() {
    super.initState();
    if (AppPush.isConfigured) {
      AppPush.onOpened = (message) {
        final router = ref.read(appRouterProvider);
        handlePushOpened(router, message);
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final router = ref.watch(appRouterProvider);
    ref.watch(appHapticsEnabledProvider);
    // Warm primary catalogs during bootstrap so tab switches / search do not
    // hitch on cold network+decode. Home later reuses the same cached futures.
    ref
      ..watch(homeRoutesProvider)
      ..watch(routesListProvider)
      ..watch(placesListProvider)
      ..watch(topTravelersProvider);

    return MaterialApp.router(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
