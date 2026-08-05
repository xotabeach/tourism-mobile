import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/routes/data/route_reviews_repository.dart';

final routeReviewsProvider = FutureProvider.autoDispose
    .family<RouteReviewsPage, String>((ref, routeId) {
      return ref.watch(routeReviewsRepositoryProvider).listPublished(routeId);
    });

final myRouteReviewsProvider = FutureProvider.autoDispose<List<RouteReview>>((
  ref,
) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return const [];
  }
  return ref.watch(routeReviewsRepositoryProvider).listMine();
});
