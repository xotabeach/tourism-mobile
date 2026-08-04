import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_match/presentation/route_match_ai_safety.dart';

void main() {
  group('route match AI safety', () {
    test('flags explicit self-harm intent', () {
      expect(
        routeMatchLooksLikeSelfHarm(
          'разбежавшись прыгну со скалы на закате',
        ),
        isTrue,
      );
      expect(routeMatchLooksLikeSelfHarm('покончить с собой'), isTrue);
      expect(routeMatchLooksLikeSelfHarm('хочу умереть'), isTrue);
    });

    test('allows ordinary travel wishes', () {
      expect(
        routeMatchLooksLikeSelfHarm('хочу закат у моря и стейк'),
        isFalse,
      );
      expect(routeMatchLooksLikeSelfHarm('одиночный маршрут по Крыму'), isFalse);
    });

    test('crisis reply is supportive and non-vulgar', () {
      expect(routeMatchCrisisSupportReply.toLowerCase(), isNot(contains('пиздец')));
      expect(routeMatchCrisisSupportReply, contains('экстренной'));
    });
  });
}
