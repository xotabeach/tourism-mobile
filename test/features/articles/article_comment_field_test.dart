import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/articles/presentation/article_comments_section.dart';

import '../../support/test_overrides.dart';

void main() {
  testWidgets('the blog comment field keeps its small corners in every state '
      'instead of the theme\'s round field shape', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ArticleCommentsSection(articleId: 'mock-article-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Напишите комментарий'),
    );
    final decoration = field.decoration!;
    for (final border in [
      decoration.border,
      decoration.enabledBorder,
      decoration.focusedBorder,
    ]) {
      expect(border, isA<OutlineInputBorder>());
      expect(
        (border! as OutlineInputBorder).borderRadius,
        BorderRadius.circular(12),
      );
    }
  });
}
