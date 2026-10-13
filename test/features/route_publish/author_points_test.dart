import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/presentation/author_point_sheet.dart';

// BACKEND-43: the author's own points in the editor.

RouteLocation _place(String id) =>
    RouteLocation(id: id, name: id, subtitle: '', lat: 44.5, lng: 34.1);

const _spring = RouteLocation(
  id: 'spring-1',
  name: 'Родник Кара-Су',
  subtitle: 'Родник',
  lat: 44.47,
  lng: 34.1,
  authorKind: 'spring',
);

void main() {
  test('coordinates are read from what map apps copy', () {
    expect(parseCoordinates('44.49520, 34.16630'), (44.4952, 34.1663));
    expect(parseCoordinates('44.4952 34.1663'), (44.4952, 34.1663));
    expect(parseCoordinates('44,4952 34,1663'), (44.4952, 34.1663));
    expect(parseCoordinates('где-то у моря'), isNull);
    expect(parseCoordinates('44.5'), isNull);
    expect(inCrimea(44.47, 34.1), isTrue);
    expect(inCrimea(55.75, 37.6), isFalse);
  });

  test('author points go to the server with the stops, in order', () {
    final draft = RouteDraft(
      start: _place('a'),
      stops: const [RouteStopDraft(location: _spring)],
      finish: _place('b'),
    );
    expect(draft.authorPoints.map((p) => p.id), ['spring-1']);
    expect(draft.authorPointsPayload.single, {
      'id': 'spring-1',
      'name': 'Родник Кара-Су',
      'kind': 'spring',
      'lat': 44.47,
      'lng': 34.1,
    });
    final again = RouteDraft.fromJson(draft.toJson());
    expect(again.stops.single.location.authorKind, 'spring');
  });

  test('renaming an author point is an edit of the draft', () {
    RouteDraft withName(String name) => RouteDraft(
      start: _place('a'),
      stops: [
        RouteStopDraft(
          location: RouteLocation(
            id: 'spring-1',
            name: name,
            subtitle: '',
            lat: 44.47,
            lng: 34.1,
            authorKind: 'spring',
          ),
        ),
      ],
      finish: _place('b'),
    );
    expect(
      withName('Родник').sameContentAs(withName('Родник Кара-Су')),
      isFalse,
    );
  });

  testWidgets('the sheet asks for a name and coordinates in Crimea', (
    tester,
  ) async {
    RouteLocation? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showAuthorPointSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('author-point-save')));
    await tester.tap(find.byKey(const ValueKey('author-point-save')));
    await tester.pump();
    expect(find.text('Назовите точку'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('author-point-name')),
      'Родник Кара-Су',
    );
    await tester.enterText(
      find.byKey(const ValueKey('author-point-coords')),
      '55.75, 37.61',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('author-point-save')));
    await tester.tap(find.byKey(const ValueKey('author-point-save')));
    await tester.pump();
    expect(find.text('Точка должна быть в Крыму'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('author-point-kind-spring')));
    await tester.enterText(
      find.byKey(const ValueKey('author-point-coords')),
      '44.47000, 34.10000',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('author-point-save')));
    await tester.tap(find.byKey(const ValueKey('author-point-save')));
    await tester.pumpAndSettle();
    expect(result?.name, 'Родник Кара-Су');
    expect(result?.authorKind, 'spring');
    expect(result?.lat, 44.47);
    expect(result?.id, isNotEmpty);
  });
}
