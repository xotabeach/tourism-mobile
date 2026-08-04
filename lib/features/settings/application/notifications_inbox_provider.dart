import 'package:flutter_riverpod/flutter_riverpod.dart';

enum InboxNotificationKind { commentLiked, profileLiked, routeComment }

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.actorName,
    required this.body,
    required this.kind,
    required this.isUnread,
  });

  final String id;
  final String actorName;
  final String body;
  final InboxNotificationKind kind;
  final bool isUnread;

  InboxNotification copyWith({bool? isUnread}) {
    return InboxNotification(
      id: id,
      actorName: actorName,
      body: body,
      kind: kind,
      isUnread: isUnread ?? this.isUnread,
    );
  }
}

class NotificationsInboxController
    extends StateNotifier<List<InboxNotification>> {
  NotificationsInboxController([List<InboxNotification>? seed])
    : super(List<InboxNotification>.unmodifiable(seed ?? _seed));

  static const _seed = <InboxNotification>[
    InboxNotification(
      id: 'n1',
      actorName: 'Никита',
      body: 'Оценил ваш комментарий',
      kind: InboxNotificationKind.commentLiked,
      isUnread: true,
    ),
    InboxNotification(
      id: 'n2',
      actorName: 'Никита',
      body: 'Оценил ваш профиль',
      kind: InboxNotificationKind.profileLiked,
      isUnread: true,
    ),
    InboxNotification(
      id: 'n3',
      actorName: 'Никита',
      body:
          'Оставил свой комментарий под вашим маршрутом “Крымская классика под ва…”',
      kind: InboxNotificationKind.routeComment,
      isUnread: false,
    ),
    InboxNotification(
      id: 'n4',
      actorName: 'Никита',
      body:
          'Оставил свой комментарий под вашим маршрутом “Крымская классика под ва…”',
      kind: InboxNotificationKind.routeComment,
      isUnread: false,
    ),
    InboxNotification(
      id: 'n5',
      actorName: 'Никита',
      body:
          'Оставил свой комментарий под вашим маршрутом “Крымская классика под ва…”',
      kind: InboxNotificationKind.routeComment,
      isUnread: false,
    ),
    InboxNotification(
      id: 'n6',
      actorName: 'Никита',
      body:
          'Оставил свой комментарий под вашим маршрутом “Крымская классика под ва…”',
      kind: InboxNotificationKind.routeComment,
      isUnread: false,
    ),
  ];

  int get unreadCount => state.where((n) => n.isUnread).length;

  void markAllRead() {
    state = [
      for (final n in state) n.isUnread ? n.copyWith(isUnread: false) : n,
    ];
  }

  void markRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isUnread: false) else n,
    ];
  }
}

final notificationsInboxProvider =
    StateNotifierProvider<
      NotificationsInboxController,
      List<InboxNotification>
    >((ref) {
      return NotificationsInboxController();
    });

final notificationsUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsInboxProvider).where((n) => n.isUnread).length;
});
