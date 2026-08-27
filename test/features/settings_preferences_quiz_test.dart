import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/features/settings/application/preferences_providers.dart';
import 'package:tourism_mobile/features/settings/data/preferences_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_preferences_quiz_screen.dart';

import '../support/test_overrides.dart';

void main() {
  Future<ProviderContainer> pumpQuiz(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1600);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    final container = ProviderContainer(
      overrides: testSessionOverrides(onboardingCompleted: true),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SettingsPreferencesQuizScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'account screen opens the preferences quiz, not a stub snackbar',
    (tester) async {
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
      await tester.tap(find.byTooltip('Настройки'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Настройки профиля'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Сменить предпочтения'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPreferencesQuizScreen), findsOneWidget);
      expect(find.text('Тест предпочтений появится позже'), findsNothing);
    },
  );

  testWidgets('selecting answers and saving persists them via the repository', (
    tester,
  ) async {
    final container = await pumpQuiz(tester);

    await tester.tap(find.text('Море'));
    await tester.tap(find.text('Горы'));
    await tester.tap(find.text('Средний'));
    await tester.tap(find.text('Путешествую с детьми'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Предпочтения сохранены'), findsOneWidget);

    final saved = await container
        .read(preferencesRepositoryProvider)
        .getPreferences();
    expect(saved.categories, containsAll(['Море', 'Горы']));
    expect(saved.difficulty, 'moderate');
    expect(saved.travelsWithKids, isTrue);
    expect(saved.travelsWithPets, isFalse);
    expect(saved.isCompleted, isTrue);
  });

  testWidgets('reopening the quiz prefills previously saved answers', (
    tester,
  ) async {
    final repo = MockPreferencesRepository();
    await repo.updatePreferences(
      categories: const ['Еда'],
      difficulty: 'hard',
      travelsWithKids: false,
      travelsWithPets: true,
    );

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
          ...testSessionOverrides(onboardingCompleted: true),
          preferencesRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SettingsPreferencesQuizScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final foodChipText = tester.widget<Text>(find.text('Еда'));
    expect(foodChipText.style?.color, Colors.white);
    final hardChipText = tester.widget<Text>(find.text('Сложный'));
    expect(hardChipText.style?.color, Colors.white);
  });
}
