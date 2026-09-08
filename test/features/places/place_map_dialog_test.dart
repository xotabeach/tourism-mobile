import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/core/device/external_maps.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/places/presentation/place_details_screen.dart';
import 'package:tourism_mobile/routing/app_router.dart';

import '../../support/test_overrides.dart';

/// "Посмотреть на карте" used to raise a 72%-tall bottom sheet with a drag
/// handle — it read as a half-open drawer around a small map rather than a
/// look at where the place is. It is a card over a dimmed page now, and the
/// space under the map carries what people came to do with a coordinate.
Future<void> _openPlace(WidgetTester tester) async {
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
      child: const TourismApp(),
    ),
  );
  await tester.pumpAndSettle();
  final welcomeCta = find.text('Начать путешествие');
  if (welcomeCta.evaluate().isNotEmpty) {
    await tester.tap(welcomeCta);
    await tester.pumpAndSettle();
  }
  final context = tester.element(find.byType(HomeScreen));
  unawaited(
    GoRouter.of(context).pushNamed(
      AppRouteNames.placeDetails,
      pathParameters: {'id': 'mock-ai-petri'},
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(PlaceDetailsScreen), findsOneWidget);
}

void main() {
  testWidgets('the map opens as a card over the page, not a sheet', (
    tester,
  ) async {
    await _openPlace(tester);

    await tester.tap(find.text('Посмотреть на карте'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('place-map-dialog')), findsOneWidget);
    // A dialog, so the page behind stays visible and dimmed.
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    // Smaller than the screen in both directions — that gap is the dimming.
    final size = tester.getSize(find.byKey(const ValueKey('place-map-dialog')));
    expect(size.width, lessThan(393));
    expect(size.height, lessThan(1600));

    // The actions people came for.
    expect(find.byKey(const ValueKey('place-map-navigate')), findsOneWidget);
    expect(find.byKey(const ValueKey('place-map-copy')), findsOneWidget);
    expect(find.byKey(const ValueKey('place-map-share')), findsOneWidget);
    expect(find.text('Проложить маршрут'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('place-map-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('place-map-dialog')), findsNothing);
    expect(find.byType(PlaceDetailsScreen), findsOneWidget);
  });

  testWidgets('tapping the dimmed area closes the map', (tester) async {
    await _openPlace(tester);

    await tester.tap(find.text('Посмотреть на карте'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('place-map-dialog')), findsOneWidget);

    // Top-left corner is barrier, never the card: the card is inset by 20/48.
    await tester.tapAt(const Offset(6, 6));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('place-map-dialog')), findsNothing);
  });

  group('external maps links', () {
    test('iOS tries Apple Maps before the web fallback', () {
      final links = ExternalMaps.candidates(
        lat: 44.4519,
        lng: 34.0567,
        label: 'Ай-Петри',
        platform: TargetPlatform.iOS,
      );
      expect(links.first.scheme, 'maps');
      expect(links.last.host, 'www.google.com');
      // Every candidate carries the point, so whichever answers is right.
      for (final link in links) {
        expect(link.toString(), contains('44.4519'));
        expect(link.toString(), contains('34.0567'));
      }
    });

    test('Android hands the point to whatever the user set as default', () {
      final links = ExternalMaps.candidates(
        lat: 44.4519,
        lng: 34.0567,
        label: 'Ай-Петри',
        platform: TargetPlatform.android,
      );
      // geo: is the intent every maps app registers — naming one app instead
      // would override a choice the user already made.
      expect(links.first.scheme, 'geo');
      expect(links.last.scheme, 'https');
    });

    test('a nameless place still gets a usable link', () {
      final links = ExternalMaps.candidates(
        lat: 44.4519,
        lng: 34.0567,
        label: '   ',
        platform: TargetPlatform.iOS,
      );
      expect(links.first.toString(), contains('44.4519%2C34.0567'));
    });

    test('anything else falls back to the web link alone', () {
      final links = ExternalMaps.candidates(
        lat: 44.4519,
        lng: 34.0567,
        label: 'Ай-Петри',
        platform: TargetPlatform.macOS,
      );
      expect(links.length, 1);
      expect(links.single.scheme, 'https');
    });
  });
}
