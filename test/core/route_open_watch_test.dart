import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/diagnostics/route_open_watch.dart';

// FRONTEND-85, spec 47 D11: a route page that never appears is noticed.

void main() {
  late List<(String, String)> blank;

  setUp(() {
    blank = [];
    RouteOpenWatch.onBlankScreen = (id, from) => blank.add((id, from));
  });

  tearDown(RouteOpenWatch.reset);

  testWidgets('a page that appears in time is not reported', (tester) async {
    RouteOpenWatch.expect('r1', from: '/search');
    await tester.pump(const Duration(seconds: 1));
    RouteOpenWatch.shown('r1');
    await tester.pump(const Duration(seconds: 5));
    expect(blank, isEmpty);
  });

  testWidgets('a page that never appears is reported with where it was asked', (
    tester,
  ) async {
    RouteOpenWatch.expect('r1', from: '/place/p1');
    await tester.pump(
      RouteOpenWatch.timeout + const Duration(milliseconds: 10),
    );
    expect(blank, [('r1', '/place/p1')]);
  });
}
