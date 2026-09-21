import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_publish_screen.dart';

import '../../support/test_overrides.dart';

void main() {
  testWidgets('a draft typed, left and reopened is still there', (
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
    await pumpTourismAppAtHome(tester);

    GoRouter.of(
      tester.element(find.byType(HomeScreen)),
    ).go(RoutePublishScreen.routePath);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Мой маршрут');
    await tester.pump();

    // Straight back, before the autosave pause runs out.
    GoRouter.of(tester.element(find.byType(RoutePublishScreen))).go('/');
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RoutePublishScreen), findsNothing);

    GoRouter.of(
      tester.element(find.byType(HomeScreen)),
    ).go(RoutePublishScreen.routePath);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Мой маршрут'), findsWidgets);
  });
}
