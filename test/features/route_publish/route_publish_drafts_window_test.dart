import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_publish_screen.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/data/mock_routes_repository.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

import '../../support/test_overrides.dart';

final class _MyDrafts extends MockRoutesRepository {
  @override
  Future<RouteListPage> listMyRoutes() async => const RouteListPage(
    items: [
      RouteSummary(
        id: 'mine',
        name: 'Ялта за день',
        slug: 'mine',
        shortDescription: '',
        stopsCount: 2,
        source: 'user_created',
        publicationStatus: 'draft',
      ),
      RouteSummary(
        id: 'ai',
        name: 'Крым · Природа',
        slug: 'ai',
        shortDescription: '',
        stopsCount: 4,
        source: 'generated',
        publicationStatus: 'draft',
      ),
    ],
    total: 2,
    limit: 100,
    offset: 0,
  );
}

void main() {
  testWidgets('opening the form offers the saved drafts in a window', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 900);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });
    await pumpTourismAppAtHome(
      tester,
      overrides: [routesRepositoryProvider.overrideWithValue(_MyDrafts())],
    );

    GoRouter.of(
      tester.element(find.byType(HomeScreen)),
    ).go(RoutePublishScreen.routePath);
    await tester.pumpAndSettle();

    expect(find.text('У вас есть черновики'), findsOneWidget);
    expect(find.text('Ялта за день'), findsOneWidget);
    expect(find.text('Крым · Природа'), findsOneWidget);
    // Only the assistant's draft carries the mark.
    expect(
      find.byKey(const ValueKey('route-draft-assistant-badge')),
      findsOneWidget,
    );
    expect(find.text('ИИ-помощник'), findsOneWidget);

    await tester.tap(find.text('Начать новый маршрут'));
    await tester.pumpAndSettle();
    expect(find.text('У вас есть черновики'), findsNothing);

    // «Мои черновики» brings the same window back, not a bottom sheet.
    await tester.enterText(find.byType(TextField).first, 'Новый');
    await tester.pumpAndSettle();
    final myDrafts = find.byKey(const ValueKey('route-draft-my-drafts'));
    await tester.ensureVisible(myDrafts);
    await tester.tap(myDrafts);
    await tester.pumpAndSettle();
    expect(find.text('У вас есть черновики'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('У вас есть черновики'), findsNothing);
    expect(find.text('Новый'), findsWidgets);
  });
}
