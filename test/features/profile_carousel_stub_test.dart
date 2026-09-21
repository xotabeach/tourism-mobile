import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/articles/presentation/widgets/article_card.dart';
import 'package:tourism_mobile/features/profile/presentation/profile_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

import '../support/test_overrides.dart';

Future<void> _openOwnProfile(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 2600);
  addTearDown(() {
    tester.view
      ..resetDevicePixelRatio()
      ..resetPhysicalSize();
  });
  await pumpTourismAppAtHome(tester);
  await tester.tap(find.bySemanticsLabel('Профиль'));
  await tester.pumpAndSettle();
  expect(find.byType(ProfileScreen), findsOneWidget);
}

/// Swipes the carousel that holds [card] until its last page is shown.
Future<void> _swipeToEnd(WidgetTester tester, Finder card) async {
  final pageView = find
      .ancestor(of: card.first, matching: find.byType(PageView))
      .first;
  await tester.ensureVisible(pageView);
  await tester.pumpAndSettle();
  for (var i = 0; i < 12; i++) {
    await tester.drag(pageView, const Offset(-400, 0));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('own profile ends the routes carousel with «Новый маршрут»', (
    tester,
  ) async {
    await _openOwnProfile(tester);
    final routesStub = find.byKey(const ValueKey('profile-routes-stub'));
    expect(routesStub, findsNothing, reason: 'built lazily at the end');

    await _swipeToEnd(tester, find.byType(RouteHeroCard));
    expect(routesStub, findsOneWidget);
    expect(find.text('Новый маршрут'), findsOneWidget);
    expect(find.text('Опубликовать маршрут'), findsOneWidget);
  });

  testWidgets('own profile ends the articles carousel with «Новая статья»', (
    tester,
  ) async {
    await _openOwnProfile(tester);
    final articlesStub = find.byKey(const ValueKey('profile-articles-stub'));
    await _swipeToEnd(tester, find.byType(ArticleCard));
    expect(articlesStub, findsOneWidget);
    expect(find.text('Новая статья'), findsOneWidget);
    expect(find.text('Написать статью'), findsWidgets);
  });
}
