import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/profile/presentation/follow_list_screen.dart';
import 'package:tourism_mobile/features/search/presentation/universal_search_panel.dart';

import '../support/test_overrides.dart';

void main() {
  test('the followers title declines regular Russian first names', () {
    expect(followersTitle('Никита Можаров'), 'Подписчики Никиты');
    expect(followersTitle('Ольга'), 'Подписчики Ольги');
    expect(followersTitle('Мария'), 'Подписчики Марии');
    expect(followersTitle('Иван'), 'Подписчики Ивана');
    expect(followersTitle('Андрей'), 'Подписчики Андрея');
    expect(followersTitle('Игорь'), 'Подписчики Игоря');
    // Anything unusual keeps the plain title rather than a wrong ending.
    expect(followersTitle('traveler_92'), 'Подписчики');
    expect(followersTitle('Путешественник 12'), 'Подписчики Путешественника');
    expect(followersTitle(''), 'Подписчики');
    expect(followersTitle(null), 'Подписчики');
  });

  testWidgets('the list shows its count and narrows by name', (tester) async {
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
          home: Scaffold(
            body: FollowListScreen(
              kind: FollowListKind.followers,
              userId: 'user-2',
              displayName: 'Никита Можаров',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Подписчики Никиты (3)'), findsOneWidget);
    expect(find.byType(DiscoveryProfileCard), findsNWidgets(3));
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'мария');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveryProfileCard), findsOneWidget);
    expect(find.text('Мария Крымская'), findsOneWidget);
    // The count in the title is the whole list, not the search result.
    expect(find.text('Подписчики Никиты (3)'), findsOneWidget);
  });
}
