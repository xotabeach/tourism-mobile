import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/profile/data/mock_profile.dart';
import 'package:tourism_mobile/features/profile/presentation/user_content_list_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

import '../support/test_overrides.dart';

void main() {
  testWidgets('«Все маршруты» of another user lists every route with a count', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 2400);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });
    const routes = MockProfile.publishedRoutes;
    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: const MaterialApp(
          home: Scaffold(
            body: UserContentListScreen(
              userId: 'user-2',
              kind: UserContentKind.routes,
              initialRoutes: routes,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Все маршруты (${routes.length})'), findsOneWidget);
    expect(find.byType(RouteHeroCard), findsNWidgets(routes.length));
  });
}
