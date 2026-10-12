import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_list_skeleton.dart';
import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/companion_sheets.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';

/// «Мои группы» in the favorites menu (FRONTEND-73): the groups going on
/// now first, so a lobby left for later is one tap away, then the walks
/// that are over with their postcards.
List<Widget> companionGroupsSlivers(AsyncValue<List<CompanionGroup>> groups) =>
    groups.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const [
        SliverToBoxAdapter(
          child: AppListSkeleton(rows: 3, rowHeight: 84, tiles: true),
        ),
      ],
      error: (_, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Consumer(
            builder: (context, ref, _) => AppAsyncErrorView(
              onRetry: () => ref.invalidate(myCompanionGroupsProvider),
            ),
          ),
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Center(
                  child: Text(
                    'Групп пока нет. Собрать друзей можно на странице '
                    'маршрута, в блоке «Пройти вместе»',
                    textAlign: TextAlign.center,
                    style: AppTypography.settingsRowSubtitle,
                  ),
                ),
              ),
            ),
          ];
        }
        final live = [
          for (final g in items)
            if (g.status.isLive) g,
        ];
        final past = [
          for (final g in items)
            if (!g.status.isLive) g,
        ];
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
            sliver: SliverList.list(
              children: [
                for (final group in live) ...[
                  CompanionGroupTile(group: group),
                  const SizedBox(height: 12),
                ],
                if (past.isNotEmpty) ...[
                  if (live.isNotEmpty) const SizedBox(height: 8),
                  const Text('Прошедшие', style: AppTypography.sectionTitle),
                  const SizedBox(height: 12),
                  for (final group in past) ...[
                    CompanionGroupTile(group: group),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        ];
      },
    );

/// One group as a row: the organizer's character, the route and where the
/// group is.
class CompanionGroupTile extends StatelessWidget {
  const CompanionGroupTile({required this.group, super.key});

  final CompanionGroup group;

  String get _status => switch (group.status) {
    _ when group.isInvitation => '${group.organizerName} зовёт вас',
    _ when group.isRequest => 'Ждёте, когда впустят',
    CompanionGroupStatus.gathering => 'Собираетесь у костра',
    CompanionGroupStatus.started => 'Группа в пути',
    CompanionGroupStatus.settled => 'Маршрут пройден',
    CompanionGroupStatus.cancelled => 'Группа распалась',
  };

  @override
  Widget build(BuildContext context) {
    final live = group.status.isLive;
    final joined = group.members
        .where((m) => m.state == CompanionMemberState.joined)
        .length;
    final organizer = group.members.where((m) => m.isOrganizer).firstOrNull;
    return Semantics(
      button: true,
      label: '«${group.routeName}», $_status, $joined из ${group.maxMembers}',
      excludeSemantics: true,
      child: Material(
        color: live ? FlatPalette.paper : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => openCompanionGroup(context, group.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 60,
                  child: CustomPaint(
                    painter: _OrganizerBean(
                      userId: organizer?.userId ?? group.organizerUserId,
                      hat: organizer?.beanHat,
                      dim: !live,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.routeName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: AppColors.primaryInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (live) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: FlatPalette.flameOuter,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              '$_status · $joined из ${group.maxMembers}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.settingsRowSubtitle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primaryInk,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrganizerBean extends CustomPainter {
  const _OrganizerBean({required this.userId, this.hat, this.dim = false});

  final String userId;
  final String? hat;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    paintBean(
      canvas,
      Offset(size.width / 2, size.height - 2),
      size.height * 0.62,
      FlatPalette.beanFor(userId),
      BeanPose(
        look: BeanLook.forUser(userId, hat: hat),
        lookX: 0.4,
        dim: dim,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _OrganizerBean old) =>
      old.userId != userId || old.hat != hat || old.dim != dim;
}
