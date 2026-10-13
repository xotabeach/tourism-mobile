import 'package:flutter/widgets.dart';

import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/home_lobby_card.dart';
import 'package:tourism_mobile/features/route_execution/application/home_active_run.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/active_route_card.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

/// What stands in the «Подбери маршрут» banner's place (FRONTEND-34,
/// FRONTEND-73).
///
/// A group still gathering at the fire, or an invitation, comes first: a
/// paused run elsewhere must not hide it. Then a run in progress, with a
/// «Группа» pill when it is the group's walk; then a group already on the
/// way without a run here. The banner stays while these load, so people with
/// neither never see it blink.
Widget homeTopCard({HomeActiveRun? run, CompanionGroup? lobby}) =>
    switch ((run, lobby)) {
      (_, final lobby?)
          when lobby.status == CompanionGroupStatus.gathering ||
              lobby.isInvitation =>
        HomeLobbyCard(group: lobby),
      (final run?, final lobby) => ActiveRouteCard(
        state: run,
        groupId: lobby != null && lobby.routeId == run.run.routeId
            ? lobby.id
            : null,
      ),
      (null, final lobby?) => HomeLobbyCard(group: lobby),
      (null, null) => const BuildRouteBanner(),
    };
