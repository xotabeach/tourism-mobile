import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/places/presentation/place_details_screen.dart';
import 'package:tourism_mobile/features/places/presentation/places_catalog_screen.dart';
import 'package:tourism_mobile/features/shared/presentation/placeholder_tab_screen.dart';
import 'package:tourism_mobile/routing/shell/app_shell_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

abstract final class AppRouteNames {
  static const home = 'home';
  static const places = 'places';
  static const placeDetails = 'place-details';
  static const routes = 'routes';
  static const favorites = 'favorites';
  static const profile = 'profile';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: HomeScreen.routePath,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.home,
                path: HomeScreen.routePath,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.places,
                path: PlacesCatalogScreen.routePath,
                builder: (context, state) => const PlacesCatalogScreen(),
                routes: [
                  GoRoute(
                    name: AppRouteNames.placeDetails,
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return PlaceDetailsScreen(placeId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.routes,
                path: '/routes',
                builder: (context, state) => const PlaceholderTabScreen(
                  title: 'Маршруты',
                  message:
                      'Редакционные маршруты появятся в Phase 4. '
                      'Вкладка уже в shell.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.favorites,
                path: '/favorites',
                builder: (context, state) => const PlaceholderTabScreen(
                  title: 'Избранное',
                  message:
                      'Избранное появится после Phase 6–7 (auth + favorites).',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.profile,
                path: '/profile',
                builder: (context, state) => const PlaceholderTabScreen(
                  title: 'Профиль',
                  message: 'Профиль и вход — Phase 6.',
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
