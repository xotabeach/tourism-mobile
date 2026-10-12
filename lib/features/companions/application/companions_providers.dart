import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/features/companions/data/api_companions_repository.dart';
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

final invitablePeopleProvider =
    FutureProvider.autoDispose<List<InvitablePerson>>(
      (ref) => ref.watch(companionsRepositoryProvider).invitable(),
    );

/// The current person's id, to find themselves among the members.
final myUserIdProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider.select((s) => s.userId)),
);
