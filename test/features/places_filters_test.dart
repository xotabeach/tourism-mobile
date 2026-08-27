import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/places/presentation/places_catalog_screen.dart';
import 'package:tourism_mobile/routing/app_router.dart';

import '../support/test_overrides.dart';

void main() {
  Future<void> pumpToPlaces(WidgetTester tester) async {
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
        overrides: testSessionOverrides(
          onboardingCompleted: true,
          displayName: 'Никита Можаров',
        ),
        child: const TourismApp(),
      ),
    );
    await tester.pumpAndSettle();
    final _welcomeCta = find.text('Начать путешествие');
    if (_welcomeCta.evaluate().isNotEmpty) {
      await tester.tap(_welcomeCta);
      await tester.pumpAndSettle();
    }

  }

  Future<void> openPlacesCatalog(WidgetTester tester) async {
    await pumpToPlaces(tester);
    final context = tester.element(find.byType(HomeScreen));
    unawaited(GoRouter.of(context).pushNamed(AppRouteNames.places));
    await tester.pumpAndSettle();
  }

  testWidgets('filter button opens the filters bottom sheet', (tester) async {
    await openPlacesCatalog(tester);

    expect(find.byType(PlacesCatalogScreen), findsOneWidget);
    expect(find.text('Места Крыма'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Фильтры'));
    await tester.pumpAndSettle();

    expect(find.text('Фильтры:'), findsWidgets);
    expect(find.text('Сложность'), findsOneWidget);
    expect(find.text('Вход'), findsOneWidget);
    expect(find.text('Любая'), findsWidgets);
  });

  testWidgets('choosing paid filter and applying shows places', (tester) async {
    await openPlacesCatalog(tester);
    await tester.tap(find.bySemanticsLabel('Фильтры'));
    await tester.pumpAndSettle();

    // Select «Платно» in the paid section (inside the bottom sheet).
    final paidChip = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('Платно'),
    );
    await tester.tap(paidChip.first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Показать места'));
    await tester.pumpAndSettle();

    expect(find.text('Места Крыма'), findsOneWidget);
  });
}
