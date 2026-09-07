import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/articles/presentation/widgets/article_card.dart';
import 'package:tourism_mobile/features/home/presentation/all_list_screen.dart';

import '../../support/test_overrides.dart';

void main() {
  testWidgets('the Блоги tab lists articles instead of spinning forever', (
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
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: const MaterialApp(
          home: AllListScreen(initialMode: HomeListMode.articles),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The loader used to fall through to places in this mode, so the article
    // list stayed empty and the spinner never went away.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ArticleCard), findsWidgets);
  });
}
