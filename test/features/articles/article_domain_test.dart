import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/articles/domain/article.dart';

void main() {
  group('Article.sortedBlocks', () {
    test('orders blocks by position regardless of list order', () {
      final withBlocks = Article(
        id: 'a1',
        title: 'Заголовок',
        status: ArticleStatus.published,
        authorUserId: 'u1',
        authorDisplayName: 'Автор',
        createdAt: DateTime.utc(2026, 1, 1),
        blocks: const [
          ArticleBlock(
            id: 'b2',
            position: 1,
            blockType: ArticleBlockType.text,
            textContent: 'второй',
          ),
          ArticleBlock(
            id: 'b1',
            position: 0,
            blockType: ArticleBlockType.text,
            textContent: 'первый',
          ),
        ],
      );

      final sorted = withBlocks.sortedBlocks;

      expect(sorted.map((b) => b.id), ['b1', 'b2']);
    });

    test('isEditableByAuthor is true only for draft/rejected', () {
      for (final status in ArticleStatus.values) {
        final article = Article(
          id: 'a',
          title: 't',
          status: status,
          authorUserId: 'u',
          authorDisplayName: 'd',
          createdAt: DateTime.utc(2026, 1, 1),
        );
        final expected =
            status == ArticleStatus.draft || status == ArticleStatus.rejected;
        expect(article.isEditableByAuthor, expected, reason: status.name);
      }
    });
  });
}
