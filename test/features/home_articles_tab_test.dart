import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/articles/presentation/widgets/article_card.dart';
import 'package:tourism_mobile/features/home/presentation/all_list_screen.dart';

import '../support/test_overrides.dart';

/// Blogs joined routes and places as a third section on Home (2026-09-04).
void main() {
  testWidgets('the home toggle offers blogs and lists article cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpTourismAppAtHome(tester);

    expect(find.text('Блоги'), findsOneWidget);
    await tester.tap(find.text('Блоги'));
    await tester.pumpAndSettle();

    // The section title follows the toggle, and the feed uses the same card
    // the profile and "Читайте также" already use.
    expect(find.byType(ArticleCard), findsWidgets);
  });

  test('every home section is covered by the list screen', () {
    // A new section must be handled everywhere the screen switches on the
    // mode — title, toggle, search scope, paging — so the enum is the
    // checklist.
    expect(HomeListMode.values, hasLength(3));
    expect(HomeListMode.values, contains(HomeListMode.articles));
  });
}
