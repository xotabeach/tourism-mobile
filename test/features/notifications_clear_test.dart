import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';
import 'package:tourism_mobile/features/settings/data/notifications_repository.dart';

import '../support/test_overrides.dart';

class _Repo implements NotificationsRepository {
  final _inner = MockNotificationsRepository();
  Object? deleteError;
  @override
  Future<NotificationsPage> list() => _inner.list();

  @override
  Future<InboxNotification> markRead(String id) => _inner.markRead(id);

  @override
  Future<void> markAllRead() => _inner.markAllRead();

  final deleteCalls = <List<String>>[];
  final clearCalls = <(NotificationsClearScope, DateTime, bool)>[];

  @override
  Future<void> deleteMany(List<String> ids) async {
    deleteCalls.add(ids);
    if (deleteError != null) {
      throw deleteError!;
    }
    await _inner.deleteMany(ids);
  }

  @override
  Future<int> clear({
    required NotificationsClearScope scope,
    required DateTime before,
    bool dryRun = false,
  }) {
    clearCalls.add((scope, before, dryRun));
    return _inner.clear(scope: scope, before: before, dryRun: dryRun);
  }
}

Future<(ProviderContainer, _Repo)> _setup() async {
  final repo = _Repo();
  final container = ProviderContainer(
    overrides: [
      ...testSessionOverrides(onboardingCompleted: true),
      notificationsRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  await container.read(notificationsInboxProvider.future);
  return (container, repo);
}

void main() {
  test(
    'queueDelete hides rows at once and undo restores them in order',
    () async {
      final (c, repo) = await _setup();
      final n = c.read(notificationsInboxProvider.notifier);
      final before = c.read(notificationsInboxProvider).value!;
      n.queueDelete([before[0], before[1]]);
      expect(
        c.read(notificationsInboxProvider).value!.length,
        before.length - 2,
      );
      n.undoPending();
      final after = c.read(notificationsInboxProvider).value!;
      expect(after.map((e) => e.id).toSet(), before.map((e) => e.id).toSet());
      for (var i = 1; i < after.length; i++) {
        expect(after[i - 1].createdAt.isBefore(after[i].createdAt), isFalse);
      }
      expect(repo.deleteCalls, isEmpty);
    },
  );

  test(
    'pending rows survive softRefresh and are deleted after the window',
    () async {
      final (c, repo) = await _setup();
      final n = c.read(notificationsInboxProvider.notifier);
      final first = c.read(notificationsInboxProvider).value!.first;
      n.queueDelete([first]);
      await n.softRefresh();
      expect(
        c.read(notificationsInboxProvider).value!.any((e) => e.id == first.id),
        isFalse,
      );
      await n.flushPending();
      expect(repo.deleteCalls.single, [first.id]);
      expect(n.pendingCount, 0);
    },
  );

  testWidgets('timer flushes after the undo window', (tester) async {
    final (c, repo) = await _setup();
    final n = c.read(notificationsInboxProvider.notifier);
    n.queueDelete([c.read(notificationsInboxProvider).value!.first]);
    await tester.pump(notificationsUndoWindow - const Duration(seconds: 1));
    expect(repo.deleteCalls, isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(repo.deleteCalls, hasLength(1));
  });

  test('failed delete restores rows and bumps the failure counter', () async {
    final (c, repo) = await _setup();
    repo.deleteError = const NetworkFailure();
    final n = c.read(notificationsInboxProvider.notifier);
    final total = c.read(notificationsInboxProvider).value!.length;
    n.queueDelete([c.read(notificationsInboxProvider).value!.first]);
    await n.flushPending();
    expect(c.read(notificationsInboxProvider).value!.length, total);
    expect(c.read(notificationsDeleteFailedProvider), 1);
  });

  test('already-deleted rows (404) are dropped quietly', () async {
    final (c, repo) = await _setup();
    repo.deleteError = const NotFoundFailure();
    final n = c.read(notificationsInboxProvider.notifier);
    final total = c.read(notificationsInboxProvider).value!.length;
    n.queueDelete([c.read(notificationsInboxProvider).value!.first]);
    await n.flushPending();
    expect(c.read(notificationsInboxProvider).value!.length, total - 1);
    expect(c.read(notificationsDeleteFailedProvider), 0);
  });

  test(
    'bulk clear of read keeps unread and uses newest loaded boundary',
    () async {
      final (c, repo) = await _setup();
      final n = c.read(notificationsInboxProvider.notifier);
      final items = c.read(notificationsInboxProvider).value!;
      final newest = items
          .map((e) => e.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      expect(await n.previewClear(NotificationsClearScope.read), 1);
      final deleted = await n.clearBulk(NotificationsClearScope.read);
      expect(deleted, 1);
      expect(repo.clearCalls.last.$2, newest);
      expect(repo.clearCalls.first.$3, isTrue);
      expect(
        c.read(notificationsInboxProvider).value!.every((e) => e.isUnread),
        isTrue,
      );
    },
  );

  test('bulk clear of all empties the inbox', () async {
    final (c, _) = await _setup();
    final n = c.read(notificationsInboxProvider.notifier);
    await n.clearBulk(NotificationsClearScope.all);
    expect(c.read(notificationsInboxProvider).value, isEmpty);
  });
}
