import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/settings/data/support_faq_content.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_support_screens.dart';

void main() {
  test('bundles fifteen articles with stable and unique source IDs', () {
    final all = [
      ...kRoutesNavigationFaq,
      ...kAppQuestionsFaq,
      ...kTravelPointsFaq,
    ];
    expect(all, hasLength(15));
    expect(all.map((item) => item.articleId).toSet(), hasLength(15));
    expect(all.every((item) => item.revision > 0), isTrue);
    expect(kRoutesNavigationFaq.map((item) => item.id), [
      'difficulty',
      'offline',
      'route-error',
      'order',
      'season',
    ]);
    expect(
      kAppQuestionsFaq.map((item) => item.id),
      containsAll(['login', 'support']),
    );
    expect(
      kTravelPointsFaq.first.answer,
      allOf(contains('автор маршрута'), isNot(contains('появится позже'))),
    );
  });

  Future<void> pumpAnswer(
    WidgetTester tester, {
    String category = 'routes',
    String questionId = 'offline',
    double textScale = 1,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: SettingsFaqAnswerScreen(
            category: category,
            questionId: questionId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('long FAQ is complete and scrollable at large text size', (
    tester,
  ) async {
    await pumpAnswer(tester, textScale: 1.5);
    final answer = kRoutesNavigationFaq.firstWhere(
      (item) => item.id == 'offline',
    );
    final text = tester.widget<Text>(find.text(answer.answer));
    expect(text.maxLines, isNull);
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(find.text('Справка КрымТрип'), findsOneWidget);
    expect(find.text('Асистент поддержки'), findsNothing);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown article does not silently display the first answer', (
    tester,
  ) async {
    await pumpAnswer(tester, questionId: 'missing-source');
    expect(find.text('Вопрос не найден'), findsOneWidget);
    expect(find.text(kRoutesNavigationFaq.first.answer), findsNothing);
  });

  testWidgets('unknown category has an honest empty state', (tester) async {
    await pumpAnswer(tester, category: 'unknown');
    expect(find.text('Вопрос не найден'), findsOneWidget);
  });

  testWidgets('new contact article can be opened without an AI call', (
    tester,
  ) async {
    await pumpAnswer(tester, category: 'app', questionId: 'support');
    final answer = kAppQuestionsFaq.firstWhere((item) => item.id == 'support');
    expect(find.text(answer.answer), findsOneWidget);
    expect(find.text('Справка КрымТрип'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
