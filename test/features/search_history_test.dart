import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/search/application/search_history_provider.dart';

void main() {
  test('keeps only the last query and drops older ones', () async {
    final store = MemorySearchHistoryStore();
    final controller = SearchHistoryController(
      store: store,
      ownerKey: 'user-a',
    );
    addTearDown(controller.dispose);

    await controller.record('Крым');
    await controller.record('море');
    await controller.record('Крым');
    expect(controller.state, ['Крым']);

    for (var i = 0; i < 7; i++) {
      await controller.record('запрос $i');
    }
    expect(controller.state, ['запрос 6']);
    expect(controller.state.length, searchHistoryMaxItems);
    expect(await store.load('user-a'), ['запрос 6']);
  });

  test('trims previously stored multi-query history on load', () async {
    final store = MemorySearchHistoryStore();
    await store.save('guest', [
      'новый',
      'второй',
      'третий',
      'четвёртый',
      'пятый',
      'шестой',
      'седьмой',
    ]);
    final controller = SearchHistoryController(store: store, ownerKey: 'guest');
    addTearDown(controller.dispose);

    await Future<void>.delayed(Duration.zero);
    expect(controller.state, ['новый']);
    expect(await store.load('guest'), ['новый']);
  });

  test('rejects short and oversized queries', () async {
    final controller = SearchHistoryController(
      store: MemorySearchHistoryStore(),
      ownerKey: 'guest',
    );
    addTearDown(controller.dispose);

    await controller.record('к');
    await controller.record('  ');
    await controller.record('x' * (searchHistoryMaxChars + 1));
    expect(controller.state, isEmpty);

    await controller.record('ок');
    expect(controller.state, ['ок']);
  });

  test(
    'history stays hidden in the current session and appears on the next',
    () async {
      final controller = SearchHistoryController(
        store: MemorySearchHistoryStore(),
        ownerKey: 'guest',
      );
      addTearDown(controller.dispose);

      controller.beginSession();
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleHistory, isEmpty);
      controller.endSession(lastQuery: 'море');
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, ['море']);

      controller.beginSession();
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleHistory, ['море']);
      controller.endSession(lastQuery: 'горы');
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleHistory, isEmpty);
      expect(controller.state, ['горы']);

      controller.beginSession();
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleHistory, ['горы']);
    },
  );
}
