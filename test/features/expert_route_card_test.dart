import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_expert_style.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

import '../support/test_overrides.dart';

void main() {
  test('route summary reads expert author contract', () {
    final route = RouteSummary.fromJson({
      'id': 'route-1',
      'name': 'Экспертный маршрут',
      'slug': 'expert-route',
      'short_description': null,
      'stops_count': 2,
      'author_is_expert': true,
    });

    expect(route.authorIsExpert, isTrue);
  });

  testWidgets('expert route uses shared frame, avatar and badge', (
    tester,
  ) async {
    const route = RouteSummary(
      id: 'route-expert',
      name: 'Гора Чок-Сары-Кая',
      slug: 'chok-sary-kaya',
      shortDescription: 'Видовой маршрут',
      stopsCount: 2,
      authorLabel: 'Никита',
      authorIsExpert: true,
      publicationStatus: 'draft',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 361,
              child: RouteHeroCard(route: route, interactive: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppExpertFrame), findsNWidgets(1));
    expect(find.byType(AppExpertBadge), findsOneWidget);
    expect(find.text('Эксперт'), findsOneWidget);
  });
}
