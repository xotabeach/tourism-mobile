import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/search/application/search_history_provider.dart';

void main() {
  test(
    'search history stores XSS-like text as data and bounds length',
    () async {
      final store = MemorySearchHistoryStore();
      final controller = SearchHistoryController(
        store: store,
        ownerKey: 'user<script>',
      );
      addTearDown(controller.dispose);

      await controller.record('<script>alert(1)</script>');
      expect(controller.state, ['<script>alert(1)</script>']);

      final oversized = 'аб' * 80;
      expect(oversized.length, greaterThan(searchHistoryMaxChars));
      await controller.record(oversized);
      expect(controller.state, ['<script>alert(1)</script>']);

      final loaded = await store.load('user<script>');
      expect(loaded, ['<script>alert(1)</script>']);
      expect(
        loaded.every((item) => item.length <= searchHistoryMaxChars),
        isTrue,
      );
    },
  );
}
