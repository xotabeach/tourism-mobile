import 'package:tourism_mobile/features/routes/domain/route.dart';

/// Local profile snapshot for Phase 5 UI. Durable profile/auth — Phase 6–7.
class ProfileAchievement {
  const ProfileAchievement({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
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
  });

  final String displayName;
  final ProfileRank rank;
  final String coverImageAsset;
  final String avatarImageAsset;
  final String? avatarImageUrl;
  final String? coverImageUrl;
  final List<List<ProfileAchievement>> achievementPages;
  final List<RouteSummary> publishedRoutes;

  String get firstName {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? 'Путник' : parts.first;
  }
}
