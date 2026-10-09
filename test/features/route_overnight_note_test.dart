import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/route_details_screen.dart';

import '../support/test_overrides.dart';

// FRONTEND-67: the night between two days is a tile of its own.

RouteStop _stop(int position, String name) => RouteStop(
  id: 's$position',
  position: position,
  placeId: 'p$position',
  placeName: name,
  placeSlug: 'p$position',
  visitDurationMinutes: 60,
  note: 'Заметка о месте',
);

final _route = RouteDetail(
  id: 'two-days',
  name: 'Симферополь и скифская столица',
  slug: 'two-days',
  shortDescription: 'Два дня',
  description: 'Полное описание маршрута',
  stopsCount: 4,
  ownerUserId: 'mock-user',
  visibility: 'private',
  publicationStatus: 'draft',
  source: 'user_created',
  media: const [],
  stops: [
    _stop(1, 'Неаполь Скифский'),
    _stop(2, 'Екатерининский сад'),
    _stop(3, 'Мечеть Эски-Сарай'),
    _stop(4, 'Мраморная пещера'),
  ],
  days: const [
    RouteDay(
      dayIndex: 1,
      firstStopId: 's1',
      lastStopId: 's2',
      overnightNote: 'Ночлег: Симферополь',
    ),
    RouteDay(dayIndex: 2, firstStopId: 's3', lastStopId: 's4'),
  ],
);

void main() {
  testWidgets('the night is a tile between the days, place in bold', (
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          ownRouteDetailProvider.overrideWith((ref, id) async => _route),
        ],
        child: MaterialApp(
          home: RouteDetailsScreen(routeId: _route.id, initialRoute: _route),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final label = find.text('Ночлег');
    final place = find.text('Симферополь');
    expect(label, findsOneWidget);
    expect(place, findsOneWidget);
    expect(tester.widget<Text>(place).style?.fontWeight, FontWeight.w600);
    expect(find.text('Ночлег: Симферополь'), findsNothing);

    // Between the last stop of day one and the heading of day two.
    final y = tester.getCenter(place).dy;
    expect(
      y,
      greaterThan(tester.getCenter(find.text('Екатерининский сад')).dy),
    );
    expect(y, lessThan(tester.getCenter(find.textContaining('День 2')).dy));
    // The moon sits in the column of the stop numbers.
    final moon = tester.getCenter(find.byIcon(Icons.bedtime_outlined)).dx;
    final numbers = [
      for (final element in find.text('2').evaluate())
        tester.getCenter(find.byElementPredicate((e) => e == element)).dx,
    ];
    expect(numbers.any((dx) => (dx - moon).abs() <= 1), isTrue);
  });
}
