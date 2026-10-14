import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/companion_sheets.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/campfire_scene.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';

/// A group the person is gathering with, on the home screen in place of the
/// «Подбери маршрут» banner and the same size as the run card (FRONTEND-73).
/// The camp is the group's own: its members sit at the fire in their hats.
class HomeLobbyCard extends StatelessWidget {
  const HomeLobbyCard({required this.group, super.key});

  static const height = 246.0;

  final CompanionGroup group;

  String get _status => group.isInvitation
      ? '${group.organizerName} зовёт вас'
      : switch (group.status) {
          CompanionGroupStatus.started => 'Группа в пути',
          _ => 'Собираетесь у костра',
        };

  String get _action => group.isInvitation
      ? 'Посмотреть приглашение'
      : group.status == CompanionGroupStatus.started
      ? 'К группе'
      : 'Вернуться в лобби';

  @override
  Widget build(BuildContext context) {
    final joined = group.members
        .where((m) => m.state == CompanionMemberState.joined)
        .length;
    return Semantics(
      button: true,
      label:
          '$_status, маршрут «${group.routeName}», $joined из '
          '${group.maxMembers}, ${_action.toLowerCase()}',
      excludeSemantics: true,
      child: AppPressableScale(
        borderRadius: AppRadii.card,
        onTap: () => openCompanionGroup(context, group.id),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CampfireScene(height: height, members: campMembersOf(group)),
                // The sky above the camp holds the words; a soft shade keeps
                // them readable over the stars.
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Color(0x99141A3A), Color(0x00141A3A)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Pill(
                            text: _status,
                            dot: group.isInvitation
                                ? FlatPalette.white
                                : FlatPalette.flameOuter,
                          ),
                          const Spacer(),
                          _Pill(text: '$joined из ${group.maxMembers}'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          group.routeName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.rubik,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _action,
                            style: TextStyle(
                              fontFamily: AppFonts.rubik,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Who sits at a group's fire: those inside, and those invited or asking to
/// come in, who wait at the edge.
List<CampMember> campMembersOf(CompanionGroup group) => [
  for (final member in group.members)
    if (member.state == CompanionMemberState.joined ||
        member.state == CompanionMemberState.invited ||
        member.state == CompanionMemberState.requested)
      CampMember(
        userId: member.userId,
        name: member.displayName,
        ready: member.ready,
        organizer: member.isOrganizer,
        waiting: member.state != CompanionMemberState.joined,
        hat: member.beanHat,
        kind: member.beanKind,
        outfit: member.beanOutfit,
      ),
];

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.dot});

  final String text;
  final Color? dot;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppRadii.capsule),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot case final color?) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}
