import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/settings/data/notifications_repository.dart';

export 'package:tourism_mobile/features/settings/data/notifications_repository.dart'
    show InboxNotification, InboxNotificationKind;

final notificationsInboxProvider =
    AsyncNotifierProvider<NotificationsInboxController, List<InboxNotification>>(
      NotificationsInboxController.new,
    );

final notificationsUnreadCountProvider = Provider<int>((ref) {
  final async = ref.watch(notificationsInboxProvider);
  return async.maybeWhen(
    data: (items) => items.where((n) => n.isUnread).length,
    orElse: () => 0,
  );
});

class NotificationsInboxController
    extends AsyncNotifier<List<InboxNotification>> {
  @override
  Future<List<InboxNotification>> build() async {
    final session = ref.watch(sessionProvider);
    if (!session.isAuthenticated) {
      return const [];
    }
    final page = await ref.watch(notificationsRepositoryProvider).list();
    return page.items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(notificationsRepositoryProvider).list();
      return page.items;
    });
  }

  Future<void> markAllRead() async {
    final current = state.valueOrNull ?? const <InboxNotification>[];
    state = AsyncData([
      for (final item in current) item.copyWith(isUnread: false),
    ]);
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
    } on Object {
      await refresh();
    }
  }

  Future<void> markRead(String id) async {
    final current = state.valueOrNull ?? const <InboxNotification>[];
    state = AsyncData([
      for (final item in current)
        if (item.id == id) item.copyWith(isUnread: false) else item,
    ]);
    try {
      await ref.read(notificationsRepositoryProvider).markRead(id);
    } on Object {
      await refresh();
    }
  }
}
