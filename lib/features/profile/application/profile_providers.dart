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

final profileSubscriptionsProvider = FutureProvider<List<PublicUserProfile>>((
  ref,
) async {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return const [
      PublicUserProfile(
        id: 'mock-user',
        displayName: 'Никита Можаров',
        avatarUrl: AppImages.travelerPortrait,
        coverUrl: AppImages.welcomeSunset,
        travelPoints: 12500,
        rankSlug: 'advanced_hiker',
        rankTitle: 'Продвинутый пешеход',
        nextRankPoints: 25000,
        leaderboardPlace: 1,
      ),
      PublicUserProfile(
        id: 'mock-maria',
        displayName: 'Мария Крымская',
        avatarUrl: AppImages.travelerPortrait,
        travelPoints: 8480,
        rankSlug: 'explorer',
        rankTitle: 'Исследователь',
        nextRankPoints: 15000,
        leaderboardPlace: 2,
        isExpert: true,
        expertTitle: 'Эксперт КрымТрип',
      ),
      PublicUserProfile(
        id: 'mock-artem',
        displayName: 'Артём Ветров',
        travelPoints: 740,
        rankSlug: 'novice',
        rankTitle: 'Новичок',
        nextRankPoints: 1000,
        leaderboardPlace: 3,
      ),
    ];
  }
  return ref.watch(publicProfileRepositoryProvider).subscriptions();
});

const _mockLeaderboard = [
  PublicUserProfile(
    id: 'mock-user',
    displayName: 'Никита Можаров',
    avatarUrl: AppImages.travelerPortrait,
    coverUrl: AppImages.welcomeSunset,
    travelPoints: 12500,
    rankSlug: 'advanced_hiker',
    rankTitle: 'Продвинутый пешеход',
    nextRankPoints: 25000,
    leaderboardPlace: 1,
  ),
  PublicUserProfile(
    id: 'mock-maria',
    displayName: 'Мария Крымская',
    avatarUrl: AppImages.travelerPortrait,
    travelPoints: 8480,
    rankSlug: 'explorer',
    rankTitle: 'Исследователь',
    nextRankPoints: 10000,
    leaderboardPlace: 2,
    isExpert: true,
    expertTitle: 'Эксперт КрымТрип',
  ),
  PublicUserProfile(
    id: 'mock-artem',
    displayName: 'Артём Ветров',
    travelPoints: 740,
    leaderboardPlace: 3,
  ),
];

final topTravelersProvider = FutureProvider<List<PublicUserProfile>>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) return Future.value(_mockLeaderboard);
  return ref.watch(publicProfileRepositoryProvider).leaderboard(limit: 3);
});

final travelersLeaderboardProvider = FutureProvider<List<PublicUserProfile>>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) return Future.value(_mockLeaderboard);
  return ref.watch(publicProfileRepositoryProvider).leaderboard(limit: 100);
});

final currentLeaderboardTravelerProvider = FutureProvider<PublicUserProfile?>((
  ref,
) async {
  final session = ref.watch(sessionProvider);
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return _mockLeaderboard.first;
  }
  final userId = session.userId;
  if (userId == null || userId.isEmpty) return null;
  return ref.watch(publicProfileRepositoryProvider).getUser(userId);
});

final userAchievementsProvider =
    FutureProvider.family<List<ProfileAchievement>, String>((
      ref,
      userId,
    ) async {
      final config = ref.watch(appConfigProvider);
      if (config.useMockData) {
        return [for (final page in MockProfile.achievementPages) ...page];
      }
      return ref.watch(publicProfileRepositoryProvider).achievements(userId);
    });

ProfileRank _rankFromUser(PublicUserProfile user) {
  return ProfileRank(
    title: user.rankTitle,
    progressPoints: user.travelPoints,
    nextRankPoints: user.nextRankPoints,
    leaderboardPlace: user.leaderboardPlace,
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
      displayName: userId == 'mock-maria' ? 'Мария Крымская' : 'Путешественник',
      rank: MockProfile.rank,
      coverImageAsset: AppImages.welcomeSunset,
      avatarImageAsset: AppImages.travelerPortrait,
      achievementPages: MockProfile.achievementPages,
      publishedRoutes: routes.items
          .where((route) => route.ownerUserId == userId)
          .toList(),
      isExpert: userId == 'mock-maria',
      expertTitle: userId == 'mock-maria' ? 'Эксперт КрымТрип' : null,
    );
  }

  final bundle = await ref.watch(publicProfileRepositoryProvider).fetch(userId);
  final achievements = await ref.watch(userAchievementsProvider(userId).future);
  String? resolve(String? raw) => AppImages.resolveMediaUrl(config, raw);
  final rank = _rankFromUser(bundle.user);
  final achievementPages = pageUnlockedAchievements(achievements);

  if (isOwn) {
    final own = ref.watch(profileProvider);
    final ownRoutes = await ref.watch(routesRepositoryProvider).listMyRoutes();
    return ProfileSnapshot(
      displayName: own.displayName,
      rank: rank,
      coverImageAsset: own.coverImageAsset,
      avatarImageAsset: own.avatarImageAsset,
      avatarImageUrl: own.avatarImageUrl,
      coverImageUrl: own.coverImageUrl,
      achievementPages: achievementPages,
      publishedRoutes: ownRoutes.items,
      likedByMe: false,
      isExpert: bundle.user.isExpert,
      expertTitle: bundle.user.expertTitle,
      travelPoints: bundle.user.travelPoints,
      followersCount: bundle.user.followersCount,
      followingCount: bundle.user.followingCount,
    );
  }

  return ProfileSnapshot(
    displayName: bundle.user.displayName,
    rank: rank,
    coverImageAsset: AppImages.welcomeSunset,
    avatarImageAsset: AppImages.travelerPortrait,
    avatarImageUrl: resolve(bundle.user.avatarUrl),
    coverImageUrl: resolve(bundle.user.coverUrl),
    achievementPages: achievementPages,
    publishedRoutes: bundle.routes,
    likedByMe: bundle.user.likedByMe,
    isExpert: bundle.user.isExpert,
    expertTitle: bundle.user.expertTitle,
    travelPoints: bundle.user.travelPoints,
    followersCount: bundle.user.followersCount,
    followingCount: bundle.user.followingCount,
  );
});

final profileLikeControllerProvider =
    AsyncNotifierProvider<ProfileLikeController, void>(
      ProfileLikeController.new,
    );

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
      final selfId = ref.read(sessionProvider).userId;
      if (selfId != null && selfId.isNotEmpty && selfId != userId) {
        ref.invalidate(publicProfileProvider(selfId));
      }
      ref.invalidate(profileSubscriptionsProvider);
    });
  }
}
