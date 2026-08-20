import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_expert_style.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class TravelersLeaderboardScreen extends ConsumerWidget {
  const TravelersLeaderboardScreen({super.key});

  static const routePath = 'travelers-top';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(travelersLeaderboardProvider);
    final current = ref.watch(currentLeaderboardTravelerProvider);
    final config = ref.watch(appConfigProvider);

    return SettingsScaffold(
      title: 'Топ путешественников:',
      subtitle: 'Рейтинг по очкам Тревел Поинт (тп)',
      spaceChildren: false,
      children: [
        board.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _LeaderboardLoading(),
          error: (_, _) => _LeaderboardError(
            onRetry: () {
              ref
                ..invalidate(travelersLeaderboardProvider)
                ..invalidate(currentLeaderboardTravelerProvider);
            },
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('Пока нет путешественников')),
              );
            }
            final own = current.valueOrNull;
            return Column(
              children: [
                if (own != null) ...[
                  _LeaderboardCard(
                    key: const ValueKey('leaderboard-current-user'),
                    traveler: own,
                    place: own.leaderboardPlace,
                    config: config,
                    isCurrentUser: true,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    child: Divider(height: 3, thickness: 3),
                  ),
                ],
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _LeaderboardCard(
                    traveler: items[i],
                    place: items[i].leaderboardPlace > 0
                        ? items[i].leaderboardPlace
                        : i + 1,
                    config: config,
                  ),
                  if (i == 2 && items.length > 3)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: Divider(height: 3, thickness: 3),
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({
    super.key,
    required this.traveler,
    required this.place,
    required this.config,
    this.isCurrentUser = false,
  });

  final PublicUserProfile traveler;
  final int place;
  final AppConfig config;
  final bool isCurrentUser;

  static const _podium = <int, Color>{
    1: Color(0xFFFFD000),
    2: Color(0xFFC6C6C8),
    3: Color(0xFFFFB56B),
  };

  @override
  Widget build(BuildContext context) {
    final podiumColor = _podium[place];
    final borderColor = podiumColor ?? AppColors.hairline;
    final avatar = AppImages.imageProvider(
      resolvedUrl: AppImages.resolveMediaUrl(config, traveler.avatarUrl),
      assetFallback: AppImages.travelerPortrait,
    );
    final safePlace = place > 0 ? place : 1;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.tile + 4),
        boxShadow: AppShadows.tile,
      ),
      child: AppExpertFrame(
        isExpert: traveler.isExpert,
        borderRadius: BorderRadius.circular(AppRadii.tile + 2),
        child: Material(
          color: AppColors.elevatedSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.tile),
            side: BorderSide(
              color: borderColor,
              width: podiumColor == null ? 1 : 1.4,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => unawaited(
              context.pushNamed(
                AppRouteNames.userProfile,
                pathParameters: {'userId': traveler.id},
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      _PlacePill(
                        place: safePlace,
                        isCurrentUser: isCurrentUser,
                        outline: podiumColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _PointsPill(
                          points: traveler.travelPoints,
                          nextRankPoints: traveler.nextRankPoints,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox.square(
                        dimension: 42,
                        child: AppExpertFrame(
                          isExpert: traveler.isExpert,
                          borderRadius: BorderRadius.circular(999),
                          child: CircleAvatar(
                            backgroundColor: AppColors.mistDark,
                            backgroundImage: avatar,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isCurrentUser ? 'Вы' : traveler.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.settingsRowTitle
                                        .copyWith(fontSize: 15),
                                  ),
                                ),
                                if (traveler.isExpert) ...[
                                  const SizedBox(width: 6),
                                  const AppExpertBadge(compact: true),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              traveler.rankTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.settingsRowSubtitle.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 20,
                        color: AppColors.primaryInk,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlacePill extends StatelessWidget {
  const _PlacePill({
    required this.place,
    required this.isCurrentUser,
    required this.outline,
  });

  final int place;
  final bool isCurrentUser;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    final selected = isCurrentUser;
    return Container(
      width: 104,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF247FD8) : AppColors.pageSurface,
        borderRadius: BorderRadius.circular(999),
        border: selected
            ? null
            : Border.all(color: outline ?? AppColors.hairline, width: 1.2),
      ),
      child: Text(
        'Топ $place',
        style: AppTypography.chip.copyWith(
          fontSize: 13,
          color: selected ? Colors.white : AppColors.primaryInk,
        ),
      ),
    );
  }
}

class _PointsPill extends StatelessWidget {
  const _PointsPill({required this.points, required this.nextRankPoints});

  final int points;
  final int nextRankPoints;

  @override
  Widget build(BuildContext context) {
    final target = nextRankPoints > points ? nextRankPoints : points;
    return Container(
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryInk,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${_formatPoints(points)} / ${_formatPoints(target)} тп',
        maxLines: 1,
        style: AppTypography.chip.copyWith(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _LeaderboardLoading extends StatelessWidget {
  const _LeaderboardLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Container(
            height: 102,
            decoration: BoxDecoration(
              color: AppColors.controlSurface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
          ),
        ],
      ],
    );
  }
}

class _LeaderboardError extends StatelessWidget {
  const _LeaderboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Text(
            'Не удалось загрузить рейтинг',
            style: AppTypography.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}

String _formatPoints(int points) {
  final raw = points.clamp(0, 1000000000).toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(' ');
  }
  return buffer.toString();
}
