import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/profile/presentation/profile_screen.dart';

const _testConfig = AppConfig(
  environment: AppEnvironment.local,
  apiBaseUrl: 'http://localhost:8000',
  appName: 'КрымТрип (Test)',
  dataSource: AppDataSource.mock,
);

void main() {
  testWidgets('profile tab shows mock rank, achievements and routes', (
    tester,
  ) async {
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
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          sessionProvider.overrideWith(
            (ref) => SessionController(
              const SessionState(
                onboardingCompleted: true,
                displayName: 'Никита Можаров',
              ),
            ),
          ),
        ],
        child: const TourismApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Профиль'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Никита Можаров'), findsWidgets);
    expect(find.text('Продвинутый пешеход'), findsWidgets);
    expect(find.text('1452 / 1800 тп'), findsOneWidget);
    expect(find.text('Топ 1345'), findsOneWidget);
    expect(find.text('Достижения:'), findsOneWidget);
    expect(find.text('Марафонец'), findsOneWidget);
    expect(find.text('Опубликованные маршруты'), findsOneWidget);
    expect(find.text('Гора Чок-Сары-Кая'), findsOneWidget);
  });

  testWidgets('profile renders untrusted achievement text as plain data', (
    tester,
  ) async {
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
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          sessionProvider.overrideWith(
            (ref) => SessionController(
              const SessionState(
                onboardingCompleted: true,
                displayName: '<script>alert(1)</script>',
              ),
            ),
          ),
        ],
        child: const TourismApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Профиль'));
    await tester.pumpAndSettle();

    expect(find.text('<script>alert(1)</script>'), findsWidgets);
    expect(
      find.byType(RichText).evaluate().any((element) {
        final widget = element.widget as RichText;
        return widget.text.toPlainText().contains('<script>alert(1)</script>');
      }),
      isTrue,
    );
  });
}
