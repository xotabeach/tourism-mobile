import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/features/profile/presentation/achievements_screen.dart';

import '../support/test_overrides.dart';

void main() {
  Future<void> pumpToAchievements(WidgetTester tester) async {
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

    await tester.tap(find.bySemanticsLabel('Профиль'));
    await tester.pumpAndSettle();
    // «Все» — entry link to the achievements screen.
    await tester.tap(find.text('Все'));
    await tester.pumpAndSettle();
  }

  testWidgets('achievements screen shows header, segment, search and badges', (
    tester,
  ) async {
    await pumpToAchievements(tester);

    expect(find.byType(AchievementsScreen), findsOneWidget);
    expect(find.text('Достижения:'), findsOneWidget);
    expect(find.text('Получено 10 из 15'), findsOneWidget);
    expect(find.text('Полученные'), findsOneWidget);
    expect(find.text('Все'), findsOneWidget);
    expect(find.text('Искать достижение'), findsOneWidget);
    expect(find.text('Марафонец'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsWidgets);

    expect(find.text('Ура Советам'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsWidgets);
    final firstRow = tester.getRect(
      find.byKey(const ValueKey('achievement-row-ach-marathoner')),
    );
    final secondRow = tester.getRect(
      find.byKey(const ValueKey('achievement-row-ach-same-way')),
    );
    expect(secondRow.top - firstRow.bottom, closeTo(6, 0.1));
  });

  testWidgets('achievements screen filters by segment and search', (
    tester,
  ) async {
    await pumpToAchievements(tester);

    // «Полученные» hides locked badges.
    await tester.tap(find.text('Полученные'));
    await tester.pumpAndSettle();
    expect(find.text('Подземный гость'), findsNothing);

    // Search narrows the list.
    await tester.enterText(find.byType(TextField).last, 'Марафонец');
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'Марафонец' &&
            widget.style?.fontSize == 16,
      ),
      findsOneWidget,
    );
    expect(find.text('Ранняя пташка'), findsNothing);

    // Clearing search restores the full list.
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Ранняя пташка'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'нет такого бейджа');
    await tester.pumpAndSettle();
    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Ничего не найдено')).dx,
      closeTo(393 / 2, 0.5),
    );
  });
}
