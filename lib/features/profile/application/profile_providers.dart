import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/profile/data/mock_profile.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';

final publicProfileRepositoryProvider = Provider<PublicProfileRepository>((
  ref,
) {
  return ApiPublicProfileRepository(ref.watch(dioProvider));
});

final profileProvider = Provider<ProfileSnapshot>((ref) {
  final session = ref.watch(sessionProvider);
  final config = ref.watch(appConfigProvider);
  String? resolvedOrLocal(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    if (raw.startsWith('file://')) {
      return raw;
    }
    return AppImages.resolveMediaUrl(config, raw);
  }

  return MockProfile.snapshot(
    displayName: session.displayName,
    avatarImageUrl: resolvedOrLocal(session.avatarUrl),
    coverImageUrl: resolvedOrLocal(session.coverUrl),
  );
});

ProfileRank _rankWithPoints(int travelPoints) {
  const base = MockProfile.rank;
  return ProfileRank(
    title: base.title,
    progressPoints: travelPoints,
    nextRankPoints: base.nextRankPoints,
    leaderboardPlace: base.leaderboardPlace,
  );
}

/// Public/view profile by user id. Always loads API routes; for the signed-in
/// user keeps local session avatar/cover and mock gamification chrome.
final publicProfileProvider = FutureProvider.family<ProfileSnapshot, String>((
  ref,
  userId,
) async {
  final session = ref.watch(sessionProvider);
  final config = ref.watch(appConfigProvider);
  final isOwn = session.userId != null && session.userId == userId;

  if (config.useMockData) {
    final own = ref.watch(profileProvider);
    if (isOwn) {
      return own;
    }
    final routes = await ref.watch(routesRepositoryProvider).listRoutes();
    return ProfileSnapshot(
      displayName: 'Путешественник',
      rank: MockProfile.rank,
      coverImageAsset: AppImages.welcomeSunset,
      avatarImageAsset: AppImages.travelerPortrait,
      achievementPages: MockProfile.achievementPages,
      publishedRoutes: routes.items
          .where((route) => route.ownerUserId == userId)
          .toList(),
    );
  }

  final bundle = await ref.watch(publicProfileRepositoryProvider).fetch(userId);
  String? resolve(String? raw) => AppImages.resolveMediaUrl(config, raw);
  final rank = _rankWithPoints(bundle.user.travelPoints);

  if (isOwn) {
    final own = ref.watch(profileProvider);
    return ProfileSnapshot(
      displayName: own.displayName,
      rank: rank,
      coverImageAsset: own.coverImageAsset,
      avatarImageAsset: own.avatarImageAsset,
      avatarImageUrl: own.avatarImageUrl,
      coverImageUrl: own.coverImageUrl,
      achievementPages: own.achievementPages,
      publishedRoutes: bundle.routes,
      likedByMe: false,
      travelPoints: bundle.user.travelPoints,
    );
  }

  return ProfileSnapshot(
    displayName: bundle.user.displayName,
    rank: rank,
    coverImageAsset: AppImages.welcomeSunset,
    avatarImageAsset: AppImages.travelerPortrait,
    avatarImageUrl: resolve(bundle.user.avatarUrl),
    coverImageUrl: resolve(bundle.user.coverUrl),
    achievementPages: MockProfile.achievementPages,
    publishedRoutes: bundle.routes,
    likedByMe: bundle.user.likedByMe,
    travelPoints: bundle.user.travelPoints,
  );
});

final profileLikeControllerProvider =
    AsyncNotifierProvider<ProfileLikeController, void>(ProfileLikeController.new);

class ProfileLikeController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> toggle(String userId) async {
    final current = ref.read(publicProfileProvider(userId)).valueOrNull;
    final liked = current?.likedByMe ?? false;
    final repo = ref.read(publicProfileRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (liked) {
        await repo.unlike(userId);
      } else {
        await repo.like(userId);
      }
      ref.invalidate(publicProfileProvider(userId));
    });
  }
}
