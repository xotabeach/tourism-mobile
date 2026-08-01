import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/routing/shell/app_shell_screen.dart';

void main() {
  group('floatingNavCompactCenterX', () {
    test('parks on slot center so profile compact has zero lateral travel', () {
      const width = 350.0;
      const profileIndex = 4;
      const slotCenter = (profileIndex + 0.5) * (width / 5);
      final compactCenter = floatingNavCompactCenterX(
        width: width,
        compactDestinationIndex: profileIndex,
      );

      expect(compactCenter, slotCenter);

      // Legacy edge parking sat a few px to the right of the profile slot —
      // that delta is exactly the sideways drift users saw Profile→Settings.
      const activeDiameter = 58.0;
      const edgePark = width - activeDiameter / 2;
      expect(edgePark - slotCenter, greaterThan(4));
    });

    test('home/routes compact parks on first slot, not the left edge', () {
      const width = 350.0;
      const slotCenter = 0.5 * (width / 5);
      final compactCenter = floatingNavCompactCenterX(
        width: width,
        compactDestinationIndex: 0,
      );
      expect(compactCenter, slotCenter);

      const activeDiameter = 58.0;
      const edgePark = activeDiameter / 2;
      expect((slotCenter - edgePark).abs(), greaterThan(4));
    });

    test(
      'active destination translation stays zero across compact progress',
      () {
        const width = 350.0;
        const index = 4;
        final compactCenter = floatingNavCompactCenterX(
          width: width,
          compactDestinationIndex: index,
        );
        const slotCenter = (index + 0.5) * (width / 5);
        for (final progress in [0.0, 0.25, 0.5, 0.75, 1.0]) {
          final translationX = (compactCenter - slotCenter) * progress;
          expect(translationX, 0);
        }
      },
    );
  });
}
