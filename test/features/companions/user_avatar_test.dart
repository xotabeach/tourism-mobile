import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/bean_portrait.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';
import 'package:tourism_mobile/features/companions/presentation/user_avatar.dart';

import '../../support/test_overrides.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ({String? kind, String? hat})? mine,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      ...testSessionOverrides(onboardingCompleted: true),
      myBeanLookProvider.overrideWith((ref) async => mine),
    ],
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  ),
);

void main() {
  // FRONTEND-97: no picture of one's own, the character's portrait instead.
  testWidgets('without a picture the avatar is the character in its hat', (
    tester,
  ) async {
    await _pump(
      tester,
      const UserAvatar(
        userId: 'anna',
        avatarUrl: null,
        beanKind: 'round',
        beanHat: 'cowboy',
        size: 48,
      ),
    );
    final portrait = tester.widget<BeanPortrait>(find.byType(BeanPortrait));
    expect(portrait.look.kind, BeanKind.round);
    expect(portrait.look.accessory, BeanHat.cowboy);
    expect(tester.getSize(find.byType(BeanPortrait)), const Size(48, 48));
  });

  testWidgets('with a picture there is no portrait', (tester) async {
    await _pump(
      tester,
      const UserAvatar(
        userId: 'anna',
        avatarUrl: 'https://example.com/a.jpg',
        size: 48,
      ),
    );
    expect(find.byType(BeanPortrait), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('one\'s own portrait follows the character just chosen', (
    tester,
  ) async {
    await _pump(
      tester,
      const UserAvatar(userId: 'me', avatarUrl: null, size: 48, own: true),
      mine: (kind: 'tall', hat: 'crown'),
    );
    await tester.pump();
    final portrait = tester.widget<BeanPortrait>(find.byType(BeanPortrait));
    expect(portrait.look.kind, BeanKind.tall);
    expect(portrait.look.accessory, BeanHat.crown);
  });

  test(
    'someone who chose nothing gets the character the account was given',
    () {
      final given = BeanLook.forUser('anna');
      expect(given.kind, BeanKind.forUser('anna'));
    },
  );
}
