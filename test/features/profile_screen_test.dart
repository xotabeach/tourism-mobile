import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/features/profile/presentation/profile_screen.dart';
import 'package:tourism_mobile/routing/app_router.dart';

import '../support/test_overrides.dart';

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
        overrides: testSessionOverrides(
          onboardingCompleted: true,
          displayName: 'Никита Можаров',
        ),
        child: const TourismApp(),
      ),
    );
    await tester.pumpAndSettle();
    final welcomeCta = find.text('Начать путешествие');
    if (welcomeCta.evaluate().isNotEmpty) {
      await tester.tap(welcomeCta);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.bySemanticsLabel('Профиль'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('Никита Можаров'), findsWidgets);
    expect(find.text('Продвинутый пешеход'), findsWidgets);
    expect(find.text('12500 / 25000 тп'), findsOneWidget);
    expect(find.text('Топ 1345'), findsOneWidget);
    expect(find.text('Достижения:'), findsOneWidget);
    expect(find.text('Подписчиков'), findsOneWidget);
    expect(find.text('Подписок'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-followers-stat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile-following-stat')),
      findsOneWidget,
    );
    final coverRect = tester.getRect(
      find.byKey(const ValueKey('profile-cover')),
    );
    final rankRect = tester.getRect(
      find.byKey(const ValueKey('profile-rank-card')),
    );
    // Card tucks under the cover photo — nudged up a bit further per user
    // feedback so it overlaps the background more than the raw Frame
    // 146/147 measurement.
    expect(coverRect.bottom - rankRect.top, closeTo(41, 0.5));
    final statImages = tester
        .widgetList<Image>(
          find.descendant(
            of: find.byKey(const ValueKey('profile-rank-card')),
            matching: find.byType(Image),
          ),
        )
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((image) => image.assetName)
        .toSet();
    expect(
      find.byKey(const ValueKey('profile-followers-icon')),
      findsOneWidget,
    );
    expect(
      statImages,
      contains(AppIconography.profileAsset(AppIconography.heart)),
    );
    expect(find.text('Марафонец'), findsOneWidget);
    expect(find.text('Мои маршруты'), findsOneWidget);
    expect(find.text('Гора Чок-Сары-Кая'), findsOneWidget);

    final pullRank = find.byKey(const ValueKey('profile-pull-rank'));
    expect(
      tester.widget<Transform>(pullRank).transform.storage[13],
      closeTo(0, 0.01),
    );
    final fixedIdentity = tester.getTopLeft(
      find.byKey(const ValueKey('profile-fixed-identity')),
    );
    final pullGesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('profile-cover'))),
    );
    await pullGesture.moveBy(const Offset(0, 100));
    await tester.pump();
    expect(
      tester.widget<Transform>(pullRank).transform.storage[13],
      greaterThan(0),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('profile-fixed-identity'))),
      fixedIdentity,
    );
    await pullGesture.up();
    await tester.pumpAndSettle();
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
        overrides: testSessionOverrides(
          onboardingCompleted: true,
          displayName: '<script>alert(1)</script>',
        ),
        child: const TourismApp(),
      ),
    );
    await tester.pumpAndSettle();
    final welcomeCta = find.text('Начать путешествие');
    if (welcomeCta.evaluate().isNotEmpty) {
      await tester.tap(welcomeCta);
      await tester.pumpAndSettle();
    }

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

  testWidgets('expert public profile exposes expert visual semantics', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1200);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: const TourismApp(),
      ),
    );
    await tester.pumpAndSettle();
    final welcomeCta = find.text('Начать путешествие');
    if (welcomeCta.evaluate().isNotEmpty) {
      await tester.tap(welcomeCta);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.bySemanticsLabel('Профиль'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ProfileScreen));
    unawaited(
      GoRouter.of(context).pushNamed(
        AppRouteNames.userProfile,
        pathParameters: const {'userId': 'mock-maria'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Профиль эксперта')), findsOneWidget);
    expect(find.text('Мария Крымская'), findsWidgets);
    expect(find.text('Подписчиков'), findsOneWidget);
    expect(find.text('Подписок'), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('profile-followers-stat')))
          .width,
      greaterThan(300),
    );
    expect(find.byKey(const ValueKey('profile-following-stat')), findsNothing);
    // Experts carry an admin-granted rank, not a points-based one — no
    // progress bar / leaderboard row, and the "Звание" value is the expert
    // label rather than the points rank title.
    expect(find.text('Эксперт КрымТрип'), findsOneWidget);
    expect(find.textContaining(' тп'), findsNothing);
    expect(find.textContaining('Топ '), findsNothing);
  });
}
