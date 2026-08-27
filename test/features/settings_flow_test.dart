import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_notifications_inbox_screen.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_prefs_screens.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_screen.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_support_screens.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_travel_plus_checkout_screen.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_travel_plus_screen.dart';

import '../support/test_overrides.dart';

void main() {
  Future<void> pumpAuthedApp(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1600);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(
          onboardingCompleted: true,
          displayName: 'Никита Можаров',
        ),
        child: const TourismApp(),
      ),
    );
    await tester.pumpAndSettle();
    final _welcomeCta = find.text('Начать путешествие');
    if (_welcomeCta.evaluate().isNotEmpty) {
      await tester.tap(_welcomeCta);
      await tester.pumpAndSettle();
    }

  }

  testWidgets('profile more opens settings root', (tester) async {
    await pumpAuthedApp(tester);
    await tester.tap(find.bySemanticsLabel('Профиль'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Настройки профиля'), findsOneWidget);
    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('Оффлайн маршруты'), findsOneWidget);
    expect(find.text('ТРЕВЕЛ'), findsWidgets);
    expect(find.text('Первый месяц бесплатно'), findsOneWidget);
  });

  testWidgets('settings notifications and offline are reachable', (
    tester,
  ) async {
    await pumpAuthedApp(tester);
    await tester.tap(find.bySemanticsLabel('Профиль'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Уведомления').first);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsNotificationsScreen), findsOneWidget);
    expect(find.text('Пуш-уведомления'), findsOneWidget);
    expect(find.text('Вибрация в приложении'), findsOneWidget);
    expect(find.textContaining('Новых уведомлений'), findsOneWidget);

    await tester.tap(find.text('Уведомления').last);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsNotificationsInboxScreen), findsOneWidget);
    expect(find.text('Мои уведомления:'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Оффлайн маршруты'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsOfflineScreen), findsOneWidget);
    expect(find.text('Кэш приложения'), findsOneWidget);
    expect(find.text('Кеш API мест и маршрутов'), findsOneWidget);
  });

  testWidgets('support faq and travel plus open from settings', (tester) async {
    await pumpAuthedApp(tester);
    await tester.tap(find.bySemanticsLabel('Профиль'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Поддержка'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsSupportScreen), findsOneWidget);

    await tester.tap(find.text('Маршруты и навигация'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsFaqCategoryScreen), findsOneWidget);
    expect(find.text('Уровень сложности'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Первый месяц бесплатно'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsTravelPlusScreen), findsOneWidget);
    expect(find.text('999 ₽/год'), findsOneWidget);
    expect(find.text('99 ₽/мес'), findsOneWidget);
    expect(find.text('Продолжить'), findsNothing);
    expect(find.byKey(const ValueKey('app-shell-bottom-scrim')), findsNothing);
    expect(find.text('Первый месяц бесплатно'), findsWidgets);
    expect(find.text('Поддержка и обратная связь'), findsOneWidget);

    await tester.tap(find.text('99 ₽/мес'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsTravelPlusCheckoutScreen), findsOneWidget);
    expect(find.text('Оформление подписки'), findsOneWidget);
    expect(find.text('Оформить подписку'), findsOneWidget);
    expect(find.text('Месяц/Год'), findsOneWidget);
    expect(find.text('CVC/CVV'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-shell-bottom-scrim')), findsNothing);
  });
}
