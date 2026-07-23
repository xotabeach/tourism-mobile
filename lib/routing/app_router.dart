import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/places/presentation/place_details_screen.dart';
import 'package:tourism_mobile/features/places/presentation/places_catalog_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: HomeScreen.routePath,
    routes: [
      GoRoute(
        path: HomeScreen.routePath,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: PlacesCatalogScreen.routePath,
        builder: (context, state) => const PlacesCatalogScreen(),
      ),
      GoRoute(
        path: PlaceDetailsScreen.routePath,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PlaceDetailsScreen(placeId: id);
        },
      ),
    ],
  );
});
