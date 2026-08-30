import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/network/client_event_id.dart';
import 'package:tourism_mobile/features/recommendations/data/api_recommendation_repository.dart';
import 'package:tourism_mobile/features/recommendations/domain/recommendation.dart';
import 'package:tourism_mobile/features/recommendations/domain/recommendation_repository.dart';

final recommendationRepositoryProvider = Provider<RecommendationRepository?>((
  ref,
) {
  if (ref.watch(appConfigProvider).useMockData) return null;
  return ApiRecommendationRepository(ref.watch(dioProvider));
});

final recommendationDeckProvider =
    FutureProvider.autoDispose<RecommendationDeck?>((ref) async {
      final repository = ref.watch(recommendationRepositoryProvider);
      return repository?.getToday();
    });

Future<void> submitRecommendationSkip(
  WidgetRef ref, {
  required String routeId,
  required DateTime deckDate,
  required String rankerVersion,
}) async {
  final repository = ref.read(recommendationRepositoryProvider);
  if (repository == null) return;
  await repository.skip(
    routeId: routeId,
    clientEventId: newClientEventId(),
    deckDate: deckDate,
    rankerVersion: rankerVersion,
  );
}

/// Whether the swiper shows the personalised deck or the plain catalogue.
///
/// Session-scoped on purpose: it is a "what am I looking at right now" switch,
/// not a durable account preference.
final showRecommendationsProvider = StateProvider<bool>((ref) => true);

Future<void> refreshRecommendationDeck(WidgetRef ref) async {
  final repository = ref.read(recommendationRepositoryProvider);
  if (repository == null) return;
  await repository.refreshToday();
  ref.invalidate(recommendationDeckProvider);
}
