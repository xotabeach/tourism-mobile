import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tourism_mobile/core/device/device_info.dart';
import 'package:tourism_mobile/features/settings/data/support_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_support_screens.dart';

import '../support/test_overrides.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1600);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          deviceAndVersionLabelProvider.overrideWith(
            (ref) async => 'Версия 1.2.3 (45). Test Device, iOS 18.0.',
          ),
        ],
        child: MaterialApp(home: Scaffold(body: screen)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('app-error report screen uses screenshot wording', (
    tester,
  ) async {
    await pumpScreen(tester, const SettingsReportAppFormScreen());

    expect(find.text('Скриншот проблемы (рекомендуется):'), findsOneWidget);
    expect(find.text('Добавить скриншот'), findsOneWidget);
    expect(find.text('Добавить фото'), findsNothing);
  });

  testWidgets('route-error report screen uses photo wording', (tester) async {
    await pumpScreen(tester, const SettingsReportRouteFormScreen());

    expect(find.text('Фото проблемы (рекомендуется):'), findsOneWidget);
    expect(find.text('Добавить фото'), findsOneWidget);
    expect(find.text('Добавить скриншот'), findsNothing);
  });

  testWidgets(
    'device card shows the real, platform-resolved version instead of '
    'the old hardcoded string',
    (tester) async {
      await pumpScreen(tester, const SettingsReportAppFormScreen());

      expect(
        find.text('Версия 1.2.3 (45). Test Device, iOS 18.0.'),
        findsOneWidget,
      );
      expect(
        find.text('Версия 0.32.1 (Бета). Iphone 16, IOS 27.'),
        findsNothing,
      );
    },
  );

  test(
    'uploadReportAttachments sends every picked photo to the ticket',
    () async {
      final repo = _RecordingSupportRepository();
      final images = [XFile('/tmp/a.jpg'), XFile('/tmp/b.jpg')];

      await uploadReportAttachments(repo, ticketId: 't-1', images: images);

      expect(repo.uploaded, [('t-1', '/tmp/a.jpg'), ('t-1', '/tmp/b.jpg')]);
    },
  );

  test(
    'uploadReportAttachments does not throw when a single upload fails',
    () async {
      final repo = _RecordingSupportRepository(failOn: '/tmp/bad.jpg');
      final images = [XFile('/tmp/a.jpg'), XFile('/tmp/bad.jpg')];

      await uploadReportAttachments(repo, ticketId: 't-1', images: images);

      expect(repo.uploaded, [('t-1', '/tmp/a.jpg')]);
    },
  );
}

final class _RecordingSupportRepository implements SupportRepository {
  _RecordingSupportRepository({this.failOn});

  final String? failOn;
  final uploaded = <(String, String)>[];

  @override
  Future<SupportAttachment> uploadAttachment({
    required String ticketId,
    required String filePath,
  }) async {
    if (filePath == failOn) {
      throw StateError('upload failed');
    }
    uploaded.add((ticketId, filePath));
    return SupportAttachment(id: 'a-${uploaded.length}', url: filePath);
  }

  @override
  Future<SupportTicket> createTicket({
    required String kind,
    required String subject,
    required String body,
    String? routeId,
  }) async => throw UnimplementedError();

  @override
  Future<SupportTicket> getTicket(String ticketId) async =>
      throw UnimplementedError();

  @override
  Future<List<SupportTicket>> listTickets() async => throw UnimplementedError();

  @override
  Future<SupportMessage> addMessage({
    required String ticketId,
    required String body,
  }) async => throw UnimplementedError();
}
