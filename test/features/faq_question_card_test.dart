import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/settings/presentation/settings_support_screens.dart';

import '../support/test_overrides.dart';

void main() {
  testWidgets('the question card spans the grid like the answer card', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1400);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: const MaterialApp(
          home: SettingsFaqAnswerScreen(category: 'app', questionId: 'account'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final question = tester.getSize(
      find.byKey(const ValueKey('faq-question-card')),
    );
    final answer = tester.getSize(
      find.byKey(const ValueKey('faq-answer-card')),
    );
    expect(question.width, answer.width);
    expect(question.width, greaterThan(300));
  });
}
