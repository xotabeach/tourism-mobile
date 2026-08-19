import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_shadows.dart';

void main() {
  test('shared card shadows stay inset from rounded card corners', () {
    final groups = [
      AppShadows.glass,
      AppShadows.card,
      AppShadows.tile,
      AppShadows.deck,
      AppShadows.settingsTile,
      AppShadows.settingsElevated,
    ];

    for (final shadows in groups) {
      expect(shadows, isNotEmpty);
      expect(shadows.every((shadow) => shadow.spreadRadius < 0), isTrue);
    }
  });
}
