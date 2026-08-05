import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
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
    final asyncBoard = ref.watch(travelersLeaderboardProvider);
    final config = ref.watch(appConfigProvider);

    return SettingsScaffold(
      title: 'Топ путешественников',
      subtitle: 'Рейтинг по очкам Travel Points',
      children: [
        asyncBoard.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const Text(
                  'Не удалось загрузить рейтинг',
                  style: AppTypography.sectionTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => ref.invalidate(travelersLeaderboardProvider),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('Пока нет путешественников')),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _LeaderboardTile(
                    traveler: items[i],
                    place: items[i].leaderboardPlace > 0
                        ? items[i].leaderboardPlace
                        : i + 1,
                    config: config,
                  ),
                ],
                const SizedBox(height: 72),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.traveler,
    required this.place,
    required this.config,
  });

  final PublicUserProfile traveler;
  final int place;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final avatar = AppImages.imageProvider(
      resolvedUrl: AppImages.resolveMediaUrl(config, traveler.avatarUrl),
      assetFallback: AppImages.travelerPortrait,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        onTap: () => unawaited(
          context.pushNamed(
            AppRouteNames.userProfile,
            pathParameters: {'userId': traveler.id},
          ),
        ),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            boxShadow: AppShadows.tile,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '$place',
                  style: AppTypography.sectionTitle.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.mistDark,
                backgroundImage: avatar,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      traveler.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.settingsRowTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      traveler.rankTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.settingsRowSubtitle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatPoints(traveler.travelPoints)} тп',
                style: AppTypography.chip.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatPoints(int points) {
  final raw = points.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write(' ');
    }
  }
  return buffer.toString();
}
