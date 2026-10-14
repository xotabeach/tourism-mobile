import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/data/bean_hats_repository.dart';
import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/character_screen.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';

import '../../support/test_overrides.dart';

// FRONTEND-72, FRONTEND-79: hats, the four builds, clothes and «Мой персонаж».

class _Repo extends MockBeanHatsRepository {
  _Repo() : super(travelPoints: 950);

  final selected = <String?>[];
  final kinds = <String?>[];
  final outfits = <String?>[];

  @override
  Future<BeanHatsState> select(String? slug) {
    selected.add(slug);
    return super.select(slug);
  }

  @override
  Future<BeanHatsState> selectKind(String? slug) {
    kinds.add(slug);
    return super.selectKind(slug);
  }

  @override
  Future<BeanHatsState> selectOutfit(String? slug) {
    outfits.add(slug);
    return super.selectOutfit(slug);
  }
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pump();
  await tester.tap(find.text(text));
  await tester.pump();
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
    expect(slugs, hasLength(21));
    for (final slug in slugs) {
      expect(BeanHat.fromSlug(slug), isNotNull, reason: slug);
    }
    // The hat an account starts with is one of the four free ones.
    expect(BeanHat.forUser('anyone').index, lessThan(4));
    expect(BeanLook.forUser('anyone', hat: 'crown').accessory, BeanHat.crown);
  });

  test('every build and outfit the server offers is drawn by the app', () {
    for (final (slug, _) in MockBeanHatsRepository.kindCatalog) {
      expect(BeanKind.fromSlug(slug), isNotNull, reason: slug);
    }
    for (final (slug, _, _, _) in MockBeanHatsRepository.outfitCatalog) {
      expect(BeanOutfit.fromSlug(slug), isNotNull, reason: slug);
    }
    final look = BeanLook.forUser('anyone', kind: 'tall', outfit: 'vest');
    expect(look.kind, BeanKind.tall);
    expect(look.outfit, BeanOutfit.vest);
    // Without a choice: the given build, no clothes.
    expect(BeanLook.forUser('anyone').outfit, BeanOutfit.none);
    expect(BeanLook.forUser('anyone').kind, BeanKind.forUser('anyone'));
  });

  test('every build is drawn without errors in every pose', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    for (final kind in BeanKind.values) {
      for (final outfit in BeanOutfit.values) {
        for (final pose in [
          const BeanPose(),
          const BeanPose(ready: true, wave: 1, happy: true, step: 1),
          const BeanPose(blink: true, mouthOpen: true, dim: true, bob: 0.1),
        ]) {
          paintBean(
            canvas,
            const Offset(100, 200),
            120,
            kind.color,
            BeanPose(
              look: BeanLook(
                kind: kind,
                outfit: outfit,
                accessory: BeanHat.cap,
              ),
              ready: pose.ready,
              wave: pose.wave,
              happy: pose.happy,
              step: pose.step,
              blink: pose.blink,
              mouthOpen: pose.mouthOpen,
              dim: pose.dim,
              bob: pose.bob,
            ),
          );
        }
      }
    }
    recorder.endRecording().dispose();
    // The yellow one is a kid, the green one tall, as drawn.
    expect(beanHeight(BeanKind.small, 100), lessThan(70));
    expect(beanHeight(BeanKind.tall, 100), greaterThan(130));
  });

  test('companions carry their hats', () {
    final member = CompanionMember.fromJson({
      'user_id': 'u',
      'display_name': 'Анна',
      'state': 'joined',
      'bean_hat': 'viking',
      'bean_kind': 'round',
      'bean_outfit': 'sweater',
    });
    expect(member.beanHat, 'viking');
    expect(member.beanKind, 'round');
    expect(member.beanOutfit, 'sweater');
  });

  testWidgets('open hats are worn at once, closed ones say how to get them', (
    tester,
  ) async {
    final repo = _Repo();
    await _open(tester, repo);
    expect(find.text('За очки ТП · у вас 950 ТП'), findsOneWidget);
    expect(find.text('Тревел+ и покупка'), findsOneWidget);

    await _tapText(tester, 'Соломенная шляпа');
    expect(repo.selected, ['straw_hat']);

    await _tapText(tester, 'Бандана');
    expect(repo.selected, ['straw_hat']);
    expect(find.textContaining('Откроется на 1500 ТП'), findsOneWidget);

    await _tapText(tester, 'Корона');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Купить · скоро'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a build is picked at once, clothes open like hats', (
    tester,
  ) async {
    final repo = _Repo();
    await _open(tester, repo);
    expect(find.text('Персонаж'), findsOneWidget);
    expect(find.text('Одежда'), findsOneWidget);

    await _tapText(tester, 'Красный');
    expect(repo.kinds, ['round']);

    await _tapText(tester, 'Худи');
    expect(repo.outfits, ['hoodie']);
    await _tapText(tester, 'Без одежды');
    expect(repo.outfits, ['hoodie', null]);

    // The jacket needs 1500 ТП; 950 is not enough.
    await _tapText(tester, 'Бомбер');
    expect(repo.outfits, ['hoodie', null]);
    expect(find.textContaining('Откроется на 1500 ТП'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('the state carries builds, clothes and the expert flag', () {
    final state = BeanHatsState.fromJson({
      'selected': null,
      'travel_points': 0,
      'travel_plus_active': false,
      'is_expert': true,
      'items': const <Object>[],
      'kind': 'small',
      'kinds': const [
        {'slug': 'pin', 'title': 'Синий'},
      ],
      'outfit': 'vest',
      'outfits': const [
        {
          'slug': 'vest',
          'title': 'Жилет с сумкой',
          'tier': 'premium',
          'available': true,
        },
      ],
    });
    expect(state.isExpert, isTrue);
    expect(state.kind, 'small');
    expect(state.kinds.single, ('pin', 'Синий'));
    expect(state.outfit, 'vest');
    expect(state.outfits.single.available, isTrue);
  });
}
