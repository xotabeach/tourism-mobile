import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';
import 'package:tourism_mobile/features/settings/data/notifications_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_notifications_inbox_screen.dart';

void main() {
  test('profile_like kind maps from API and uses actor headline', () {
    expect(
      inboxNotificationKindFromApi('profile_like'),
      InboxNotificationKind.profileLike,
    );
    final item = InboxNotification(
      id: 'pl',
      kind: InboxNotificationKind.profileLike,
      title: 'Новая подписка',
      body: 'Подписался на ваш профиль',
      actorDisplayName: 'Анна',
      targetType: 'user',
      targetId: 'user-2',
      isUnread: true,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    expect(item.headline, 'Анна');
  });

  test('achievement_unlocked maps from API and uses title headline', () {
    expect(
      inboxNotificationKindFromApi('achievement_unlocked'),
      InboxNotificationKind.achievementUnlocked,
    );
    final item = InboxNotification(
      id: 'ach',
      kind: InboxNotificationKind.achievementUnlocked,
      title: 'Новое достижение',
      body: 'Получено достижение «Марафонец»',
      targetType: 'achievement',
      targetId: 'ach-1',
      isUnread: true,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    expect(item.headline, 'Новое достижение');
  });

  test('clampText bounds oversized notification payloads', () {
    final oversized = 'A' * 500;
    final clamped = SettingsNotificationsInboxScreen.clampText(
      oversized,
      SettingsNotificationsInboxScreen.maxBodyChars,
    );
    expect(clamped.length, lessThanOrEqualTo(181));
    expect(clamped.endsWith('…'), isTrue);
  });

  testWidgets('XSS-like payload is rendered as plain Text only', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 900);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    const payload = '<script>alert(1)</script>';
    final seed = [
      InboxNotification(
        id: 'xss',
        kind: InboxNotificationKind.routeReview,
        title: 'Новый отзыв',
        body: 'javascript:alert(1)',
        actorDisplayName: payload,
        targetType: 'route',
        targetId: 'route-1',
        isUnread: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsInboxProvider.overrideWith(
            () => _SeedInboxController(seed),
          ),
        ],
        child: const MaterialApp(home: SettingsNotificationsInboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(payload), findsOneWidget);
    expect(find.text('javascript:alert(1)'), findsOneWidget);
    expect(find.byType(Text), findsWidgets);
  });

  testWidgets('moderation kinds render title as headline without actor', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 900);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    final seed = [
      InboxNotification(
        id: 'mod',
        kind: InboxNotificationKind.routePublished,
        title: 'Маршрут опубликован',
        body: 'Ваш маршрут «XSS<script>» прошёл модерацию',
        targetType: 'route',
        targetId: 'route-1',
        isUnread: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsInboxProvider.overrideWith(
            () => _SeedInboxController(seed),
          ),
        ],
        child: const MaterialApp(home: SettingsNotificationsInboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Маршрут опубликован'), findsOneWidget);
    expect(find.textContaining('XSS<script>'), findsOneWidget);
    expect(find.text('Путешественник'), findsNothing);
  });
}

class _SeedInboxController extends NotificationsInboxController {
  _SeedInboxController(this._seed);

  final List<InboxNotification> _seed;

  @override
  Future<List<InboxNotification>> build() async => _seed;
}
