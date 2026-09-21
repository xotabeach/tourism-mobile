import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/settings/data/notifications_repository.dart';

export 'package:tourism_mobile/features/settings/data/notifications_repository.dart'
    show InboxNotification, InboxNotificationKind, NotificationsClearScope;

final notificationsInboxProvider =
    AsyncNotifierProvider<
      NotificationsInboxController,
      List<InboxNotification>
    >(NotificationsInboxController.new);

final notificationsUnreadCountProvider = Provider<int>((ref) {
  final async = ref.watch(notificationsInboxProvider);
  final items = async.valueOrNull;
  if (items == null) {
    return 0;
  }
  return items.where((n) => n.isUnread).length;
});

/// Bumped when a background delete failed and the rows were restored.
final StateProvider<int> notificationsDeleteFailedProvider = StateProvider<int>(
  (ref) => 0,
);

const notificationsUndoWindow = Duration(seconds: 5);
const _deleteChunk = 100;

class NotificationsInboxController
    extends AsyncNotifier<List<InboxNotification>> {
  /// Rows swiped away but not yet deleted on the server (shared undo queue).
  final Map<String, InboxNotification> _pending = {};
  Timer? _flushTimer;

  int get pendingCount => _pending.length;

  List<InboxNotification> _visible(List<InboxNotification> items) => [
    for (final item in items)
      if (!_pending.containsKey(item.id)) item,
  ];

  @override
  Future<List<InboxNotification>> build() async {
    final session = ref.watch(
      sessionProvider.select((s) => (isAuthenticated: s.isAuthenticated)),
    );
    _flushTimer?.cancel();
    _pending.clear();
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
      return _visible(page.items);
    });
  }

  /// Hides [items] at once and deletes them on the server after the undo
  /// window (restarted by every new swipe).
  void queueDelete(List<InboxNotification> items) {
    if (items.isEmpty) {
      return;
    }
    for (final item in items) {
      _pending[item.id] = item;
    }
    state = AsyncData(_visible(state.valueOrNull ?? const []));
    _flushTimer?.cancel();
    _flushTimer = Timer(notificationsUndoWindow, () {
      unawaited(flushPending());
    });
  }

  /// Cancels every pending delete and brings the rows back.
  void undoPending() {
    _flushTimer?.cancel();
    if (_pending.isEmpty) {
      return;
    }
    final merged = <InboxNotification>[
      ...(state.valueOrNull ?? const []),
      ..._pending.values,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _pending.clear();
    state = AsyncData(merged);
  }

  /// Sends pending deletes now (leaving the screen, app going to background).
  Future<void> flushPending() async {
    _flushTimer?.cancel();
    if (_pending.isEmpty) {
      return;
    }
    final batch = Map<String, InboxNotification>.of(_pending);
    final repo = ref.read(notificationsRepositoryProvider);
    final ids = batch.keys.toList();
    try {
      for (var i = 0; i < ids.length; i += _deleteChunk) {
        await repo.deleteMany(
          ids.sublist(i, (i + _deleteChunk).clamp(0, ids.length)),
        );
      }
      _pending.removeWhere((id, _) => batch.containsKey(id));
    } on NotFoundFailure {
      _pending.removeWhere((id, _) => batch.containsKey(id));
    } on Object {
      _pending.removeWhere((id, _) => batch.containsKey(id));
      final merged = <InboxNotification>[
        ...(state.valueOrNull ?? const []),
        ...batch.values,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = AsyncData(merged);
      ref.read(notificationsDeleteFailedProvider.notifier).state++;
    }
  }

  /// Rows a bulk clear of [scope] would remove, counted by the server.
  Future<int> previewClear(NotificationsClearScope scope) {
    return ref
        .read(notificationsRepositoryProvider)
        .clear(scope: scope, before: _clearBoundary(), dryRun: true);
  }

  /// Clears everything up to the newest loaded row; newer rows stay.
  Future<int> clearBulk(NotificationsClearScope scope) async {
    await flushPending();
    final before = _clearBoundary();
    final deleted = await ref
        .read(notificationsRepositoryProvider)
        .clear(scope: scope, before: before);
    state = AsyncData([
      for (final item in state.valueOrNull ?? const <InboxNotification>[])
        if (item.createdAt.isAfter(before) ||
            (scope == NotificationsClearScope.read && item.isUnread))
          item,
    ]);
    unawaited(softRefresh());
    return deleted;
  }

  DateTime _clearBoundary() {
    final all = [
      ...(state.valueOrNull ?? const <InboxNotification>[]),
      ..._pending.values,
    ];
    if (all.isEmpty) {
      return DateTime.now().toUtc();
    }
    return all.map((n) => n.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Reload inbox without flashing [AsyncLoading] (keeps badge count stable).
  Future<void> softRefresh() async {
    if (!ref.read(sessionProvider).isAuthenticated) {
      state = const AsyncData([]);
      return;
    }
    try {
      final page = await ref.read(notificationsRepositoryProvider).list();
      state = AsyncData(_visible(page.items));
    } on Object {
      // Keep the previous snapshot on transient failures.
    }
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
