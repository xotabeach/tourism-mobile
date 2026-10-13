import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/data/invite_privacy_repository.dart';
import 'package:tourism_mobile/features/companions/presentation/block_person_button.dart';
import 'package:tourism_mobile/features/companions/presentation/group_qr.dart';
import 'package:tourism_mobile/features/companions/presentation/invite_privacy_screen.dart';

import '../../support/test_overrides.dart';

// FRONTEND-63: QR of the group code, who may invite me, blocking.

class _Repo extends MockInvitePrivacyRepository {
  final calls = <String>[];

  @override
  Future<void> setPolicy(InvitePolicy policy) async {
    calls.add('policy:${policy.name}');
    await super.setPolicy(policy);
  }

  @override
  Future<void> block(String userId) async {
    calls.add('block:$userId');
    await super.block(userId);
  }

  @override
  Future<void> unblock(String userId) async {
    calls.add('unblock:$userId');
    await super.unblock(userId);
  }
}

Widget _app(Widget child, _Repo repo) => ProviderScope(
  overrides: [
    ...testSessionOverrides(onboardingCompleted: true),
    invitePrivacyRepositoryProvider.overrideWithValue(repo),
  ],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  group('group QR', () {
    test('carries the code with our marker and reads it back', () {
      expect(groupQrPayload('krm12q'), 'krymtrip:group:KRM12Q');
      expect(parseGroupQr('krymtrip:group:KRM12Q'), 'KRM12Q');
      expect(parseGroupQr('  krm12q '), 'KRM12Q');
    });

    test('a foreign QR is not a code', () {
      expect(parseGroupQr('https://example.com/join/KRM12Q'), isNull);
      expect(parseGroupQr('krymtrip:group:'), isNull);
      expect(parseGroupQr('hello world'), isNull);
    });
  });

  testWidgets('who may invite me: the choice goes to the server', (
    tester,
  ) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(const InvitePrivacyScreen(), repo));
    await tester.pumpAndSettle();
    expect(find.text('Взаимные подписки'), findsOneWidget);
    expect(find.text('Никто'), findsOneWidget);
    expect(find.text('Никого нет'), findsOneWidget);

    await tester.tap(find.text('Никто'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['policy:nobody']);
    expect(await repo.policy(), InvitePolicy.nobody);
  });

  testWidgets('a blocked person can be unblocked from the settings', (
    tester,
  ) async {
    final repo = _Repo();
    await repo.block('anna');
    repo.calls.clear();
    await tester.pumpWidget(_app(const InvitePrivacyScreen(), repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Разблокировать'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['unblock:anna']);
    expect(find.text('Никого нет'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('blocking from a profile asks first', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(
      _app(
        const BlockPersonButton(
          userId: 'anna',
          displayName: 'Анна',
          blocked: false,
        ),
        repo,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('profile-block')));
    await tester.pumpAndSettle();
    expect(find.text('Заблокировать Анна?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('profile-block')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Заблокировать'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['block:anna']);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('the group QR renders for the code', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GroupQrImage(code: 'KRM12Q')),
      ),
    );
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.size, 220);
  });
}
