import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_collapsing_header.dart';
import 'package:tourism_mobile/routing/shell/app_shell_screen.dart';

import '../support/test_overrides.dart';

Future<void> _openRouteDetails(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 852);
  addTearDown(() {
    tester.view
      ..resetDevicePixelRatio()
      ..resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: testSessionOverrides(onboardingCompleted: true),
      child: const TourismApp(),
    ),
  );
  await tester.pumpAndSettle();
    final _welcomeCta = find.text('Начать путешествие');
    if (_welcomeCta.evaluate().isNotEmpty) {
      await tester.tap(_welcomeCta);
      await tester.pumpAndSettle();
    }


  await tester.tap(find.bySemanticsLabel('Маршруты'));
  await tester.pumpAndSettle();
  final coach = tester.widget<InkWell>(
    find
        .ancestor(of: find.text('Хорошо'), matching: find.byType(InkWell))
        .first,
  );
  coach.onTap!();
  await tester.pumpAndSettle();
  await tester.tap(find.text('Классика Южного берега').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('second compact Home tap leaves route details', (tester) async {
    final handle = tester.ensureSemantics();
    await _openRouteDetails(tester);

    expect(find.byType(RouteCollapsingHeader), findsOneWidget);
    final compact = find.bySemanticsLabel(
      'Развернуть навигацию, выбран раздел Главная',
    );
    expect(compact, findsOneWidget);

    // Tap 1: expand and arm compact exit.
    await tester.tap(compact);
    await tester.pumpAndSettle();

    // Auto-collapse back to compact droplet.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Развернуть навигацию, выбран раздел Главная'),
      findsOneWidget,
    );

    // Tap 2 on the same Home droplet: leave details.
    await tester.tap(
      find.bySemanticsLabel('Развернуть навигацию, выбран раздел Главная'),
    );
    await tester.pumpAndSettle();

    final path = GoRouter.of(
      tester.element(find.byType(AppFloatingNavBar)),
    ).state.uri.path;
    expect(path, anyOf('/', HomeScreen.routePath));
    expect(
      tester
          .widget<AppFloatingNavBar>(find.byType(AppFloatingNavBar))
          .currentIndex,
      0,
    );
    expect(find.byType(RouteCollapsingHeader), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Home tab after expand leaves route details', (tester) async {
    await _openRouteDetails(tester);

    await tester.tap(
      find.bySemanticsLabel('Развернуть навигацию, выбран раздел Главная'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Главная'));
    await tester.pumpAndSettle();

    expect(find.byType(RouteCollapsingHeader), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
