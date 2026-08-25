import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/features/auth/presentation/auth_identity_screen.dart';
import 'package:tourism_mobile/features/auth/presentation/auth_otp_screen.dart';
import 'package:tourism_mobile/features/home/presentation/all_list_screen.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/my_routes/presentation/my_routes_screen.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/onboarding/presentation/welcome_screen.dart';
import 'package:tourism_mobile/features/places/presentation/place_details_screen.dart';
import 'package:tourism_mobile/features/places/presentation/places_catalog_screen.dart';
import 'package:tourism_mobile/features/profile/presentation/achievements_screen.dart';
import 'package:tourism_mobile/features/profile/presentation/profile_screen.dart';
import 'package:tourism_mobile/features/profile/presentation/travelers_leaderboard_screen.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/chat_history_screen.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_results_screen.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_screen.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_publish_screen.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/route_details_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/routes_catalog_screen.dart';
import 'package:tourism_mobile/features/search/presentation/search_screen.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_account_screens.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_notifications_inbox_screen.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_prefs_screens.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_screen.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_support_screens.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_travel_plus_checkout_screen.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_travel_plus_screen.dart';
import 'package:tourism_mobile/routing/shell/app_shell_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

abstract final class AppRouteNames {
  static const welcome = 'welcome';
  static const authIdentity = 'auth-identity';
  static const authOtp = 'auth-otp';
  static const home = 'home';
  static const places = 'places';
  static const placeDetails = 'place-details';
  static const routePlaceDetails = 'route-place-details';
  static const routes = 'routes';
  static const routeDetails = 'route-details';
  static const favorites = 'favorites'; // legacy alias → routeMatch
  static const routeMatch = 'route-match';
  static const routeMatchResults = 'route-match-results';
  static const routeMatchResume = 'route-match-resume';
  static const chatHistory = 'chat-history';
  static const routePublish = 'route-publish';
  static const myRoutes = 'my-routes';
  static const profile = 'profile';
  static const achievements = 'achievements';
  static const userProfile = 'user-profile';
  static const travelersLeaderboard = 'travelers-leaderboard';
  static const homeAllList = 'home-all-list';
  static const settings = 'settings';
  static const settingsAccount = 'settings-account';
  static const settingsChangeName = 'settings-change-name';
  static const settingsChangePhoto = 'settings-change-photo';
  static const settingsChangePhone = 'settings-change-phone';
  static const settingsNotifications = 'settings-notifications';
  static const settingsNotificationsInbox = 'settings-notifications-inbox';
  static const settingsOffline = 'settings-offline';
  static const settingsSupport = 'settings-support';
  static const settingsFaqCategory = 'settings-faq-category';
  static const settingsFaqAnswer = 'settings-faq-answer';
  static const settingsChat = 'settings-chat';
  static const settingsReport = 'settings-report';
  static const settingsReportApp = 'settings-report-app';
  static const settingsReportRoute = 'settings-report-route';
  static const settingsThanks = 'settings-thanks';
  static const settingsTravelPlus = 'settings-travel-plus';
  static const settingsTravelPlusCheckout = 'settings-travel-plus-checkout';
  static const search = 'search';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: WelcomeScreen.routePath,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      if (!session.isHydrated) {
        return null;
      }
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
          (session.phone == null || session.phone!.isEmpty)) {
        return AuthIdentityScreen.routePath;
      }
      return null;
    },
    routes: [
      GoRoute(
        name: AppRouteNames.welcome,
        path: WelcomeScreen.routePath,
        pageBuilder: (context, state) =>
            _appTransitionPage(state, const WelcomeScreen()),
      ),
      GoRoute(
        name: AppRouteNames.authIdentity,
        path: AuthIdentityScreen.routePath,
        pageBuilder: (context, state) =>
            _appTransitionPage(state, const AuthIdentityScreen()),
      ),
      GoRoute(
        name: AppRouteNames.authOtp,
        path: AuthOtpScreen.routePath,
        pageBuilder: (context, state) =>
            _appTransitionPage(state, const AuthOtpScreen()),
      ),
      GoRoute(
        name: AppRouteNames.search,
        path: SearchScreen.routePath,
        pageBuilder: (context, state) =>
            _appTransitionPage(state, const SearchScreen()),
      ),
      GoRoute(
        name: AppRouteNames.routeMatchResume,
        path: '${RouteMatchScreen.routePath}/resume',
        pageBuilder: (context, state) {
          return _appTransitionPage(
            state,
            RouteMatchScreen(
              resumeSession: state.extra is RoutePlanningSession
                  ? state.extra! as RoutePlanningSession
                  : null,
            ),
          );
        },
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
                routes: [
                  // Places stay in-app but outside the tab bar.
                  GoRoute(
                    name: AppRouteNames.places,
                    path: 'places',
                    builder: (context, state) => const PlacesCatalogScreen(),
                    routes: [
                      GoRoute(
                        name: AppRouteNames.placeDetails,
                        path: ':id',
                        pageBuilder: (context, state) {
                          final id = state.pathParameters['id']!;
                          return CupertinoPage<void>(
                            key: state.pageKey,
                            child: PlaceDetailsScreen(placeId: id),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    name: AppRouteNames.travelersLeaderboard,
                    path: TravelersLeaderboardScreen.routePath,
                    pageBuilder: (context, state) {
                      return CupertinoPage<void>(
                        key: state.pageKey,
                        child: const TravelersLeaderboardScreen(),
                      );
                    },
                  ),
                  GoRoute(
                    name: AppRouteNames.homeAllList,
                    path: AllListScreen.routePath,
                    pageBuilder: (context, state) {
                      final mode = state.extra is HomeListMode
                          ? state.extra! as HomeListMode
                          : HomeListMode.routes;
                      return CupertinoPage<void>(
                        key: state.pageKey,
                        child: AllListScreen(initialMode: mode),
                      );
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
                path: RoutesCatalogScreen.routePath,
                builder: (context, state) => const RoutesCatalogScreen(),
                routes: [
                  GoRoute(
                    name: AppRouteNames.routeDetails,
                    path: ':id',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id']!;
                      final initialRoute = state.extra is RouteSummary
                          ? state.extra! as RouteSummary
                          : null;
                      return CupertinoPage<void>(
                        key: state.pageKey,
                        child: RouteDetailsScreen(
                          routeId: id,
                          initialRoute: initialRoute,
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        name: AppRouteNames.routePlaceDetails,
                        path: 'place/:placeId',
                        pageBuilder: (context, state) {
                          final placeId = state.pathParameters['placeId']!;
                          return CupertinoPage<void>(
                            key: state.pageKey,
                            child: PlaceDetailsScreen(placeId: placeId),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.routeMatch,
                path: RouteMatchScreen.routePath,
                builder: (context, state) => const RouteMatchScreen(),
                routes: [
                  GoRoute(
                    name: AppRouteNames.routeMatchResults,
                    path: RouteMatchResultsScreen.routePath,
                    pageBuilder: (context, state) {
                      return CupertinoPage<void>(
                        key: state.pageKey,
                        child: const RouteMatchResultsScreen(),
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                name: AppRouteNames.routePublish,
                path: RoutePublishScreen.routePath,
                pageBuilder: (context, state) =>
                    _appTransitionPage(state, const RoutePublishScreen()),
              ),
              // Legacy deep link used by older builds / tests.
              GoRoute(
                name: AppRouteNames.favorites,
                path: '/favorites',
                redirect: (context, state) => RouteMatchScreen.routePath,
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.myRoutes,
                path: MyRoutesScreen.routePath,
                builder: (context, state) => const MyRoutesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.profile,
                path: ProfileScreen.routePath,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    name: AppRouteNames.userProfile,
                    path: ProfileScreen.userRoutePath,
                    pageBuilder: (context, state) {
                      final userId = state.pathParameters['userId']!;
                      return CupertinoPage<void>(
                        key: state.pageKey,
                        child: ProfileScreen(userId: userId),
                      );
                    },
                  ),
                  GoRoute(
                    name: AppRouteNames.achievements,
                    path: AchievementsScreen.routePath,
                    pageBuilder: (context, state) => CupertinoPage<void>(
                      key: state.pageKey,
                      child: const AchievementsScreen(),
                    ),
                  ),
                  GoRoute(
                    name: AppRouteNames.settings,
                    path: SettingsScreen.routePath,
                    pageBuilder: (context, state) => CupertinoPage<void>(
                      key: state.pageKey,
                      child: const SettingsScreen(),
                    ),
                    routes: [
                      GoRoute(
                        name: AppRouteNames.chatHistory,
                        path: ChatHistoryScreen.routePath,
                        pageBuilder: (context, state) => CupertinoPage<void>(
                          key: state.pageKey,
                          child: const ChatHistoryScreen(),
                        ),
                      ),
                      GoRoute(
                        name: AppRouteNames.settingsAccount,
                        path: 'account',
                        pageBuilder: (context, state) => CupertinoPage<void>(
                          key: state.pageKey,
                          child: const SettingsAccountScreen(),
                        ),
                        routes: [
                          GoRoute(
                            name: AppRouteNames.settingsChangeName,
                            path: 'name',
                            pageBuilder: (context, state) =>
                                CupertinoPage<void>(
                                  key: state.pageKey,
                                  child: const SettingsChangeNameScreen(),
                                ),
                          ),
                          GoRoute(
                            name: AppRouteNames.settingsChangePhoto,
                            path: 'photo',
                            pageBuilder: (context, state) =>
                                CupertinoPage<void>(
                                  key: state.pageKey,
                                  child: const SettingsChangePhotoScreen(),
                                ),
                          ),
                          GoRoute(
                            name: AppRouteNames.settingsChangePhone,
                            path: 'phone',
                            pageBuilder: (context, state) =>
                                CupertinoPage<void>(
                                  key: state.pageKey,
                                  child: const SettingsChangePhoneScreen(),
                                ),
                          ),
                        ],
                      ),
                      GoRoute(
                        name: AppRouteNames.settingsNotifications,
                        path: 'notifications',
                        pageBuilder: (context, state) => CupertinoPage<void>(
                          key: state.pageKey,
                          child: const SettingsNotificationsScreen(),
                        ),
                        routes: [
                          GoRoute(
                            name: AppRouteNames.settingsNotificationsInbox,
                            path: 'inbox',
                            pageBuilder: (context, state) =>
                                CupertinoPage<void>(
                                  key: state.pageKey,
                                  child:
                                      const SettingsNotificationsInboxScreen(),
                                ),
                          ),
                        ],
                      ),
                      GoRoute(
                        name: AppRouteNames.settingsOffline,
                        path: 'offline',
                        pageBuilder: (context, state) => CupertinoPage<void>(
                          key: state.pageKey,
                          child: const SettingsOfflineScreen(),
                        ),
                      ),
                      GoRoute(
                        name: AppRouteNames.settingsSupport,
                        path: 'support',
                        pageBuilder: (context, state) => CupertinoPage<void>(
                          key: state.pageKey,
                          child: const SettingsSupportScreen(),
                        ),
                        routes: [
                          GoRoute(
                            name: AppRouteNames.settingsFaqCategory,
                            path: 'faq/:category',
                            pageBuilder: (context, state) =>
                                CupertinoPage<void>(
                                  key: state.pageKey,
                                  child: SettingsFaqCategoryScreen(
                                    category: state.pathParameters['category']!,
                                  ),
                                ),
                            routes: [
                              GoRoute(
                                name: AppRouteNames.settingsFaqAnswer,
                                path: ':questionId',
                                pageBuilder: (context, state) =>
                                    CupertinoPage<void>(
                                      key: state.pageKey,
                                      child: SettingsFaqAnswerScreen(
                                        category:
                                            state.pathParameters['category']!,
                                        questionId:
                                            state.pathParameters['questionId']!,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                          GoRoute(
                            name: AppRouteNames.settingsChat,
                            path: 'chat',
                            pageBuilder: (context, state) =>
                                CupertinoPage<void>(
                                  key: state.pageKey,
                                  child: const SettingsChatScreen(),
                                ),
                          ),
                          GoRoute(
                            name: AppRouteNames.settingsReport,
                            path: 'report',
                            pageBuilder: (context, state) =>
                                CupertinoPage<void>(
                                  key: state.pageKey,
                                  child: const SettingsReportScreen(),
                                ),
                            routes: [
                              GoRoute(
                                name: AppRouteNames.settingsReportApp,
                                path: 'app',
                                pageBuilder: (context, state) =>
                                    CupertinoPage<void>(
                                      key: state.pageKey,
                                      child:
                                          const SettingsReportAppFormScreen(),
                                    ),
                              ),
                              GoRoute(
                                name: AppRouteNames.settingsReportRoute,
                                path: 'route',
                                pageBuilder: (context, state) =>
                                    CupertinoPage<void>(
                                      key: state.pageKey,
                                      child:
                                          const SettingsReportRouteFormScreen(),
                                    ),
                              ),
                            ],
                          ),
                          GoRoute(
                            name: AppRouteNames.settingsThanks,
                            path: 'thanks',
                            pageBuilder: (context, state) =>
                                CupertinoPage<void>(
                                  key: state.pageKey,
                                  child: const SettingsThanksScreen(),
                                ),
                          ),
                        ],
                      ),
                      GoRoute(
                        name: AppRouteNames.settingsTravelPlus,
                        path: 'travel-plus',
                        pageBuilder: (context, state) => CupertinoPage<void>(
                          key: state.pageKey,
                          child: const SettingsTravelPlusScreen(),
                        ),
                        routes: [
                          GoRoute(
                            name: AppRouteNames.settingsTravelPlusCheckout,
                            path: 'checkout',
                            pageBuilder: (context, state) {
                              final yearly =
                                  state.uri.queryParameters['yearly'] == 'true';
                              return CupertinoPage<void>(
                                key: state.pageKey,
                                child: SettingsTravelPlusCheckoutScreen(
                                  initialYearly: yearly,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _appTransitionPage(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.normal,
    reverseTransitionDuration: AppMotion.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.standard,
        reverseCurve: Curves.easeInCubic,
      );
      if (reduceMotion) {
        return child;
      }
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.014),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen<SessionState>(sessionProvider, (_, _) => notifyListeners());
  }
}
