import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/search/application/search_history_provider.dart';

void main() {
  test('records unique newest-first history and caps at 20', () async {
    final store = MemorySearchHistoryStore();
    final controller = SearchHistoryController(
      store: store,
      ownerKey: 'user-a',
    );
    addTearDown(controller.dispose);

    await controller.record('Крым');
    await controller.record('море');
    await controller.record('Крым');
    expect(controller.state, ['Крым', 'море']);

    for (var i = 0; i < 25; i++) {
      await controller.record('запрос $i');
    }
    expect(controller.state.length, searchHistoryMaxItems);
    expect(controller.state.first, 'запрос 24');
    expect(controller.state.contains('Крым'), isFalse);
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
      expect(controller.visibleHistory, isEmpty);
      controller.endSession(lastQuery: 'море');
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, ['море']);

      controller.beginSession();
      expect(controller.visibleHistory, ['море']);
      controller.endSession(lastQuery: 'горы');
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleHistory, isEmpty);

      controller.beginSession();
      expect(controller.visibleHistory, ['горы', 'море']);
    },
  );
}
