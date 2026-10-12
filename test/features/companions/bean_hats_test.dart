import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/data/bean_hats_repository.dart';
import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/character_screen.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';

import '../../support/test_overrides.dart';

// FRONTEND-72: twenty hats and «Мой персонаж».

class _Repo extends MockBeanHatsRepository {
  _Repo() : super(travelPoints: 950);

  final selected = <String?>[];

  @override
  Future<BeanHatsState> select(String? slug) {
    selected.add(slug);
    return super.select(slug);
  }
}

Future<void> _open(WidgetTester tester, _Repo repo) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 1500);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testSessionOverrides(onboardingCompleted: true),
        beanHatsRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: CharacterScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  test('every hat the server sells is drawn by the app', () {
    final slugs = [
      for (final (slug, _, _, _) in MockBeanHatsRepository.catalog) slug,
    ];
    expect(slugs, hasLength(20));
    for (final slug in slugs) {
      expect(BeanHat.fromSlug(slug), isNotNull, reason: slug);
    }
    // The hat an account starts with is one of the four free ones.
    expect(BeanHat.forUser('anyone').index, lessThan(4));
    expect(BeanLook.forUser('anyone', hat: 'crown').accessory, BeanHat.crown);
  });

  test('companions carry their hats', () {
    final member = CompanionMember.fromJson({
      'user_id': 'u',
      'display_name': 'Анна',
      'state': 'joined',
      'bean_hat': 'viking',
    });
    expect(member.beanHat, 'viking');
  });

  testWidgets('open hats are worn at once, closed ones say how to get them', (
    tester,
  ) async {
    final repo = _Repo();
    await _open(tester, repo);
    expect(find.text('За очки ТП · у вас 950 ТП'), findsOneWidget);
    expect(find.text('Тревел+ и покупка'), findsOneWidget);

    await tester.tap(find.text('Соломенная шляпа'));
    await tester.pump();
    expect(repo.selected, ['straw_hat']);

    await tester.tap(find.text('Бандана'));
    await tester.pump();
    expect(repo.selected, ['straw_hat']);
    expect(find.textContaining('Откроется на 1500 ТП'), findsOneWidget);

    await tester.tap(find.text('Корона'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Купить · скоро'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
