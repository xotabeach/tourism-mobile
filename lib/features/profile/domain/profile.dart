import 'package:tourism_mobile/features/routes/domain/route.dart';

/// Local profile snapshot for Phase 5 UI. Durable profile/auth — Phase 6–7.
class ProfileAchievement {
  const ProfileAchievement({
    required this.id,
    required this.title,
    required this.description,
    this.isUnlocked = true,
    this.howToEarn = '',
    this.iconSlug = '',
    this.unlockedAt,
  });

  final String id;
  final String title;
  final String description;

  /// What the traveller must do to earn it.
  final String howToEarn;

  /// Icon key from the backend, so a new badge needs no app release.
  final String iconSlug;

  /// When it was earned, if it has been.
  final DateTime? unlockedAt;

  /// Whether the traveler has earned this badge. Defaults to unlocked so
  /// existing call sites keep showing the full colorful set.
  final bool isUnlocked;
}

class ProfileRank {
  const ProfileRank({
    required this.title,
    required this.progressPoints,
    required this.nextRankPoints,
    required this.leaderboardPlace,
  });

  final String title;
  final int progressPoints;
  final int nextRankPoints;
  final int leaderboardPlace;
}

class ProfileSnapshot {
  const ProfileSnapshot({
    required this.displayName,
    required this.rank,
    required this.coverImageAsset,
    required this.avatarImageAsset,
    required this.achievementPages,
    required this.publishedRoutes,
    this.avatarImageUrl,
    this.coverImageUrl,
    this.likedByMe = false,
    this.isExpert = false,
    this.expertTitle,
    this.travelPoints,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  final String displayName;
  final ProfileRank rank;
  final String coverImageAsset;
  final String avatarImageAsset;
  final String? avatarImageUrl;
  final String? coverImageUrl;
  final List<List<ProfileAchievement>> achievementPages;
  final List<RouteSummary> publishedRoutes;
  final bool likedByMe;
  final bool isExpert;

  /// Admin-granted expert label (e.g. "Эксперт КрымТрип"). Independent of
  /// the points-based [rank] — experts don't need travel points progression.
  final String? expertTitle;
  final int? travelPoints;
  final int followersCount;
  final int followingCount;

  String get firstName {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? 'Путник' : parts.first;
  }
}

List<List<ProfileAchievement>> pageUnlockedAchievements(
  List<ProfileAchievement> items, {
  int pageSize = 3,
}) {
  final unlocked = [
    for (final item in items)
      if (item.isUnlocked) item,
  ];
  if (unlocked.isEmpty) {
    return const [];
  }
  return [
    for (var i = 0; i < unlocked.length; i += pageSize)
      unlocked.sublist(
        i,
        i + pageSize > unlocked.length ? unlocked.length : i + pageSize,
      ),
  ];
}
