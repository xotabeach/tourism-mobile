import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/features/auth/presentation/auth_identity_screen.dart';
import 'package:tourism_mobile/features/auth/presentation/auth_otp_screen.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/onboarding/presentation/welcome_screen.dart';
import 'package:tourism_mobile/features/places/presentation/place_details_screen.dart';
import 'package:tourism_mobile/features/places/presentation/places_catalog_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/route_details_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/routes_catalog_screen.dart';
import 'package:tourism_mobile/features/shared/presentation/placeholder_tab_screen.dart';
import 'package:tourism_mobile/routing/shell/app_shell_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

abstract final class AppRouteNames {
  static const welcome = 'welcome';
  static const authIdentity = 'auth-identity';
  static const authOtp = 'auth-otp';
  static const home = 'home';
  static const places = 'places';
  static const placeDetails = 'place-details';
  static const routes = 'routes';
  static const routeDetails = 'route-details';
  static const favorites = 'favorites';
  static const profile = 'profile';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: WelcomeScreen.routePath,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final completed = session.onboardingCompleted;
      final loc = state.matchedLocation;
      final onOnboarding =
          loc == WelcomeScreen.routePath ||
          loc == AuthIdentityScreen.routePath ||
          loc == AuthOtpScreen.routePath;

      if (!completed && !onOnboarding) {
        return WelcomeScreen.routePath;
      }
      if (completed && onOnboarding) {
        return HomeScreen.routePath;
      }
      if (!completed &&
          loc == AuthOtpScreen.routePath &&
          (session.displayName == null || session.displayName!.isEmpty)) {
        return AuthIdentityScreen.routePath;
      }
      return null;
    },
    routes: [
      GoRoute(
        name: AppRouteNames.welcome,
        path: WelcomeScreen.routePath,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        name: AppRouteNames.authIdentity,
        path: AuthIdentityScreen.routePath,
        builder: (context, state) => const AuthIdentityScreen(),
      ),
      GoRoute(
        name: AppRouteNames.authOtp,
        path: AuthOtpScreen.routePath,
        builder: (context, state) => const AuthOtpScreen(),
      ),
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
                name: AppRouteNames.routes,
                path: RoutesCatalogScreen.routePath,
                builder: (context, state) => const RoutesCatalogScreen(),
                routes: [
                  GoRoute(
                    name: AppRouteNames.routeDetails,
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return RouteDetailsScreen(routeId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.favorites,
                path: '/favorites',
                builder: (context, state) => const PlaceholderTabScreen(
                  title: 'Подобрать маршрут',
                  message:
                      'Форма подбора маршрута появится в Phase 8A Route Builder.',
                ),
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

class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen<SessionState>(sessionProvider, (_, _) => notifyListeners());
  }
}
