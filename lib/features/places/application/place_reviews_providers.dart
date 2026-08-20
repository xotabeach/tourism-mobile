import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/places/data/place_reviews_repository.dart';
import 'package:tourism_mobile/features/routes/data/route_reviews_repository.dart';

final placeReviewsProvider = FutureProvider.autoDispose
    .family<RouteReviewsPage, String>((ref, placeId) {
      return ref.watch(placeReviewsRepositoryProvider).listPublished(placeId);
    });

final myPlaceReviewsProvider = FutureProvider.autoDispose<List<RouteReview>>((
  ref,
) async {
  if (!ref.watch(sessionProvider).isAuthenticated) return const [];
  return ref.watch(placeReviewsRepositoryProvider).listMine();
});
