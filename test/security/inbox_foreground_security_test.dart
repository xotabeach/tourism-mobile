import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/features/routes/data/route_reviews_repository.dart';
import 'package:tourism_mobile/features/routes/presentation/route_details_screen.dart';
import 'package:tourism_mobile/features/settings/data/notifications_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/inbox_foreground_host.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_notifications_inbox_screen.dart';

void main() {
  test('pendingReviewsNotYetPublished drops ids already published', () {
    RouteReview review(String id, {required String status}) {
      return RouteReview(
        id: id,
        routeId: 'r1',
        authorUserId: 'u1',
        authorDisplayName: 'A',
        authorRankTitle: 'Новичок',
        body: 'text',
        rating: 5,
        status: status,
        createdAt: DateTime.utc(2026, 1, 1),
      );
    }

    final pending = [
      review('same', status: 'pending_review'),
      review('only-pending', status: 'pending_review'),
    ];
    final published = [review('same', status: 'published')];
    final filtered = pendingReviewsNotYetPublished(
      pending: pending,
      published: published,
    );
    expect(filtered.map((e) => e.id), ['only-pending']);
  });

  test('formatBadgeCount hides zero and caps at 99+', () {
    expect(AppFlatIconButton.formatBadgeCount(0), '');
    expect(AppFlatIconButton.formatBadgeCount(3), '3');
    expect(AppFlatIconButton.formatBadgeCount(99), '99');
    expect(AppFlatIconButton.formatBadgeCount(100), '99+');
  });

  test('newUnreadNotifications returns only unseen unread rows', () {
    final items = [
      InboxNotification(
        id: 'a',
        kind: InboxNotificationKind.routePublished,
        title: 'Маршрут опубликован',
        body: 'ok',
        isUnread: true,
        createdAt: DateTime.utc(2026, 1, 2),
      ),
      InboxNotification(
        id: 'b',
        kind: InboxNotificationKind.profileLike,
        title: 'Новая подписка',
        body: 'Подписался',
        isUnread: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      InboxNotification(
        id: 'c',
        kind: InboxNotificationKind.routeRejected,
        title: 'Отклонён',
        body: 'x',
        isUnread: false,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ];
    final fresh = newUnreadNotifications(items: items, seenIds: {'a'});
    expect(fresh.map((e) => e.id), ['b']);
  });

  testWidgets('badge is shown for unread count and omitted when zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AppFlatIconButton(
                iconAsset: AppIconography.bell,
                semanticLabel: 'Уведомления, 2 новых',
                badgeCount: 2,
                onPressed: () {},
              ),
              AppFlatIconButton(
                iconAsset: AppIconography.bell,
                semanticLabel: 'Уведомления',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('app-flat-icon-badge')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('toast payload is clamped plain Text (XSS-like body)', (
    tester,
  ) async {
    const payload = '<script>alert(1)</script>';
    final clamped = SettingsNotificationsInboxScreen.clampText(
      payload,
      SettingsNotificationsInboxScreen.maxNameChars,
    );
    expect(clamped.contains('<script>'), isTrue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('<script>alert(1)</script>')),
      ),
    );
    expect(find.text(payload), findsOneWidget);
    expect(find.byType(Text), findsWidgets);
  });
}
