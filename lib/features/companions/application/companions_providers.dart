import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/features/companions/data/api_companions_repository.dart';
import 'package:tourism_mobile/features/companions/data/bean_hats_repository.dart';
import 'package:tourism_mobile/features/companions/data/invite_privacy_repository.dart';
import 'package:tourism_mobile/features/companions/data/mock_companions_repository.dart';
import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';

final companionsRepositoryProvider = Provider<CompanionsRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockData) {
    final session = ref.read(sessionProvider);
    return MockCompanionsRepository(
      meId: session.userId ?? 'mock-user',
      meName: session.displayName ?? 'Вы',
    );
  }
  return ApiCompanionsRepository(ref.watch(dioProvider));
});

/// One group as its screen sees it; the screen refreshes it while open.
final companionGroupProvider = FutureProvider.autoDispose
    .family<CompanionGroup, String>(
      (ref, id) => ref.watch(companionsRepositoryProvider).get(id),
    );

final companionProgressProvider = FutureProvider.autoDispose
    .family<CompanionProgress, String>(
      (ref, id) => ref.watch(companionsRepositoryProvider).progress(id),
    );

/// Live groups the person is in or invited to.
final myCompanionGroupsProvider =
    FutureProvider.autoDispose<List<CompanionGroup>>(
      (ref) => ref.watch(companionsRepositoryProvider).myGroups(),
    );

/// The live group a person is in or invited to, the one the home card and
/// «Перейти в активное лобби» lead to (FRONTEND-73). A request to join is
/// not one yet: the organizer has not let them in.
CompanionGroup? activeLobbyOf(List<CompanionGroup> groups) => groups
    .where((g) => g.status.isLive && (g.isInside || g.isInvitation))
    .firstOrNull;

/// The lobby the home screen shows in place of the «Подбери маршрут»
/// banner. Any failure means no card: the banner is never worse.
final homeLobbyProvider = FutureProvider.autoDispose<CompanionGroup?>((
  ref,
) async {
  if (!ref.watch(sessionProvider.select((s) => s.isAuthenticated))) {
    return null;
  }
  try {
    return activeLobbyOf(await ref.watch(myCompanionGroupsProvider.future));
  } on Object {
    return null;
  }
});

final invitablePeopleProvider =
    FutureProvider.autoDispose<List<InvitablePerson>>(
      (ref) => ref.watch(companionsRepositoryProvider).invitable(),
    );

/// The current person's id, to find themselves among the members.
final myUserIdProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider.select((s) => s.userId)),
);

final beanHatsRepositoryProvider = Provider<BeanHatsRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockData) {
    return MockBeanHatsRepository();
  }
  return ApiBeanHatsRepository(ref.watch(dioProvider));
});

final invitePrivacyRepositoryProvider = Provider<InvitePrivacyRepository>((
  ref,
) {
  if (ref.watch(appConfigProvider).useMockData) {
    return MockInvitePrivacyRepository();
  }
  return ApiInvitePrivacyRepository(ref.watch(dioProvider));
});

/// «Кто может меня приглашать» as the server has it.
final invitePolicyProvider = FutureProvider.autoDispose<InvitePolicy>(
  (ref) => ref.watch(invitePrivacyRepositoryProvider).policy(),
);

/// People I blocked, newest first.
final blockedPeopleProvider = FutureProvider.autoDispose<List<BlockedPerson>>(
  (ref) => ref.watch(invitePrivacyRepositoryProvider).blocked(),
);
