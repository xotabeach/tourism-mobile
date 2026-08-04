import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_notifications_inbox_screen.dart';

void main() {
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
    final controller = NotificationsInboxController(const [
      InboxNotification(
        id: 'xss',
        actorName: payload,
        body: 'javascript:alert(1)',
        kind: InboxNotificationKind.commentLiked,
        isUnread: true,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsInboxProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: SettingsNotificationsInboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(payload), findsOneWidget);
    expect(find.text('javascript:alert(1)'), findsOneWidget);
    expect(find.byType(Text), findsWidgets);
  });
}
