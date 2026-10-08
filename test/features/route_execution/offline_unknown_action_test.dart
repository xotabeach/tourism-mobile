import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourism_mobile/core/storage/memory_secure_storage.dart';
import 'package:tourism_mobile/features/route_execution/data/route_execution_offline_store.dart';

// FRONTEND-48: an outbox entry whose action this build does not know (written
// by a newer build before a downgrade) used to be read as «complete» and
// finished the person's route when the queue drained.

const _outboxKey = 'offline.execution.outbox.v1';

Map<String, dynamic> _raw(String id, String action, {String? stopId}) => {
  'id': id,
  'execution_id': 'e1',
  'stop_id': stopId,
  'route_id': null,
  'client_event_id': 'ce-$id',
  'action': action,
  'created_at': '2026-10-08T10:00:0${id}Z',
  'attempts': 0,
  'position': null,
};

void main() {
  test('an unknown action is not an entry, and never «complete»', () {
    final json = _raw('1', 'skipStop', stopId: 's2');

    expect(RouteExecutionOutboxEntry.tryFromJson(json), isNull);
    expect(
      () => RouteExecutionOutboxEntry.fromJson(json),
      throwsFormatException,
    );
  });

  test('every known action still round-trips', () {
    for (final action in RouteExecutionAction.values) {
      final entry = RouteExecutionOutboxEntry.fromJson(_raw('1', action.name));
      expect(entry.action, action);
      expect(RouteExecutionOutboxEntry.fromJson(entry.toJson()).action, action);
    }
  });

  group('secure store', () {
    late MemorySecureStorage storage;
    late SecureRouteExecutionOfflineStore store;

    setUp(() async {
      storage = MemorySecureStorage();
      store = SecureRouteExecutionOfflineStore(storage);
      await storage.write(
        key: _outboxKey,
        value: jsonEncode([
          _raw('1', 'completeStop', stopId: 's1'),
          _raw('2', 'skipStop', stopId: 's2'),
          _raw('3', 'pause'),
        ]),
      );
    });

    Future<List<String>> storedActions() async {
      final raw = await storage.read(key: _outboxKey);
      final items = jsonDecode(raw!) as List<dynamic>;
      return [
        for (final item in items)
          (item as Map<String, dynamic>)['action'] as String,
      ];
    }

    test('lists only the actions it can deliver', () async {
      final entries = await store.listOutbox();

      expect(entries.map((entry) => entry.action), [
        RouteExecutionAction.completeStop,
        RouteExecutionAction.pause,
      ]);
    });

    test('keeps the unknown entry through enqueue and remove', () async {
      await store.removeOutbox('1');
      await store.enqueue(
        RouteExecutionOutboxEntry.fromJson(_raw('4', 'resume')),
      );

      expect(await storedActions(), ['skipStop', 'pause', 'resume']);
    });

    test('does not delete the list while an unknown entry remains', () async {
      await store.removeOutbox('1');
      await store.removeOutbox('3');

      expect(await store.listOutbox(), isEmpty);
      expect(await storedActions(), ['skipStop']);
    });
  });

  test(
    'shared preferences store skips the unknown entry and keeps it',
    () async {
      SharedPreferences.setMockInitialValues({
        'crimeatrip.offline.execution.outbox.v1.1': jsonEncode(
          _raw('1', 'completeStop'),
        ),
        'crimeatrip.offline.execution.outbox.v1.2': jsonEncode(
          _raw('2', 'skipStop'),
        ),
      });
      final store = SharedPreferencesRouteExecutionOfflineStore();

      final entries = await store.listOutbox();

      expect(entries.map((entry) => entry.action), [
        RouteExecutionAction.completeStop,
      ]);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('crimeatrip.offline.execution.outbox.v1.2'),
        isNotNull,
      );
    },
  );
}
