import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/domain/content_tags.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';

RouteLocation _place(String id) =>
    RouteLocation(id: id, name: id, subtitle: '', lat: 44.5, lng: 34.1);

RouteDraft _draft(List<String> breaks) => RouteDraft(
  start: _place('start'),
  finish: _place('finish'),
  stops: [
    RouteStopDraft(location: _place('a')),
    RouteStopDraft(location: _place('b')),
  ],
  dayBreaks: breaks,
);

void main() {
  test('only breaks on stops still on the route are sent, in route order', () {
    // «gone» was removed from the route, «finish» cannot end a day early.
    final draft = _draft(['b', 'gone', 'a', 'finish']);
    expect(draft.validDayBreaks, ['a', 'b']);
  });

  test('day breaks survive the device copy of the draft', () {
    final again = RouteDraft.fromJson(_draft(['a']).toJson());
    expect(again.dayBreaks, ['a']);
    expect(RouteDraft.fromJson(const {}).dayBreaks, isEmpty);
  });

  test('a new day break is an edit of the draft', () {
    expect(_draft(['a']).sameContentAs(_draft([])), isFalse);
    expect(_draft(['a']).sameContentAs(_draft(['a', 'gone'])), isTrue);
  });

  test('authors can mark a route as driven', () {
    expect(routeTags, contains(carRouteTag));
    expect(articleTags, isNot(contains(carRouteTag)));
  });
}
