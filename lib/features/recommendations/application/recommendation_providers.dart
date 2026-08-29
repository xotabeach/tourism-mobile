import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
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
    clientEventId: _uuidV4(),
    deckDate: deckDate,
    rankerVersion: rankerVersion,
  );
}

String _uuidV4() {
  final random = Random();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
