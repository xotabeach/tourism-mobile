import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/articles/application/article_editor_controller.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/domain/articles_repository.dart';

/// Records what the editor sends and hands back articles whose block ids
/// mirror the position order, exactly like the real backend rebuild.
class _FakeRepository implements ArticlesRepository {
  _FakeRepository({this.failUpload = false, this.existing});

  final bool failUpload;
  final Article? existing;

  final createCalls = <List<ArticleBlockDraft>>[];
  final updateCalls = <List<ArticleBlockDraft>>[];
  final uploads = <({String articleId, String blockId, String path})>[];
  List<String> lastTags = const [];
  var submitted = false;
  var _articleCounter = 0;

  Article _articleFrom(
    String id,
    List<ArticleBlockDraft> blocks,
    String title,
  ) {
    return Article(
      id: id,
      title: title,
      status: ArticleStatus.draft,
      authorUserId: 'me',
      authorDisplayName: 'Вы',
      createdAt: DateTime.utc(2026, 9, 1),
      blocks: [
        for (var index = 0; index < blocks.length; index++)
          ArticleBlock(
            id: 'server-block-$index',
            position: index,
            blockType: blocks[index].blockType,
            textContent: blocks[index].textContent,
            caption: blocks[index].caption,
            listStyle: blocks[index].listStyle,
          ),
      ],
    );
  }

  @override
  Future<Article> getArticle(String id) async {
    final article = existing;
    if (article == null) {
      throw const NotFoundFailure();
    }
    return article;
  }

  @override
  Future<Article> createDraft({
    required String title,
    String? relatedRouteId,
    String? relatedPlaceId,
    List<String> tags = const [],
    List<ArticleBlockDraft> blocks = const [],
  }) async {
    createCalls.add(blocks);
    lastTags = tags;
    return _articleFrom('article-${++_articleCounter}', blocks, title);
  }

  @override
  Future<Article> updateDraft(
    String id, {
    required String title,
    String? relatedRouteId,
    String? relatedPlaceId,
    List<String> tags = const [],
    List<ArticleBlockDraft> blocks = const [],
  }) async {
    updateCalls.add(blocks);
    lastTags = tags;
    return _articleFrom(id, blocks, title);
  }

  @override
  Future<ArticleBlock> uploadBlockImage(
    String articleId,
    String blockId,
    String filePath,
  ) async {
    uploads.add((articleId: articleId, blockId: blockId, path: filePath));
    if (failUpload) {
      throw const NetworkFailure();
    }
    return ArticleBlock(
      id: blockId,
      position: 0,
      blockType: ArticleBlockType.image,
      imageUrl: 'https://cdn.example/$blockId.jpg',
    );
  }

  @override
  Future<Article> submitForReview(String id) async {
    submitted = true;
    return Article(
      id: id,
      title: 'Отправлено',
      status: ArticleStatus.pendingReview,
      authorUserId: 'me',
      authorDisplayName: 'Вы',
      createdAt: DateTime.utc(2026, 9, 1),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

ArticleEditorController _controller(
  _FakeRepository repository, {
  String? articleId,
}) {
  return ArticleEditorController(
    repository,
    articleId: articleId,
    autosaveDelay: const Duration(milliseconds: 10),
  );
}

void main() {
  _publishedEditingTests();
  test('a draft with no title is not saved, however much is typed', () async {
    final repository = _FakeRepository();
    final controller = _controller(repository)
      ..addBlock(ArticleBlockType.text)
      ..editBlockText('block-0', 'Текст без заголовка');

    await controller.save();

    expect(repository.createCalls, isEmpty);
    expect(controller.state.savedAt, isNull);
  });

  test(
    'the first save creates a draft and adopts the server block ids',
    () async {
      final repository = _FakeRepository();
      final controller = _controller(repository)
        ..setTitle('Заголовок')
        ..addBlock(ArticleBlockType.text)
        ..editBlockText('block-0', 'Абзац');

      await controller.save();

      expect(repository.createCalls, hasLength(1));
      expect(controller.state.articleId, 'article-1');
      expect(controller.state.blocks.single.serverId, 'server-block-0');
      expect(controller.state.savedAt, isNotNull);

      // A second save updates rather than creating a duplicate.
      controller.setTitle('Заголовок 2');
      await controller.save();
      expect(repository.createCalls, hasLength(1));
      expect(repository.updateCalls, hasLength(1));

      // ...and it names the blocks it is updating. Without the server id the
      // backend cannot tell this is the same block, so it re-creates it empty
      // and archives the uploaded photo — images vanished on the next edit
      // (2026-09-03).
      expect(repository.updateCalls.single.single.id, 'server-block-0');
    },
  );

  test(
    'an image is uploaded only after the save that mints its block id',
    () async {
      final repository = _FakeRepository();
      final controller = _controller(repository)
        ..setTitle('С картинкой')
        ..addBlock(ArticleBlockType.image)
        ..attachImage('block-0', '/tmp/photo.jpg');

      expect(
        controller.state.blocks.single.uploadStatus,
        BlockUploadStatus.waitingForSave,
      );
      expect(repository.uploads, isEmpty);

      await controller.save();

      expect(repository.uploads, hasLength(1));
      expect(repository.uploads.single.blockId, 'server-block-0');
      expect(repository.uploads.single.path, '/tmp/photo.jpg');
      expect(
        controller.state.blocks.single.uploadStatus,
        BlockUploadStatus.none,
      );
      expect(controller.state.blocks.single.imageUrl, isNotNull);
    },
  );

  test(
    'a failed upload is retried on its own, without re-saving the article',
    () async {
      final repository = _FakeRepository(failUpload: true);
      final controller = _controller(repository)
        ..setTitle('С картинкой')
        ..addBlock(ArticleBlockType.image)
        ..attachImage('block-0', '/tmp/photo.jpg');

      await controller.save();
      expect(
        controller.state.blocks.single.uploadStatus,
        BlockUploadStatus.failed,
      );
      expect(repository.createCalls, hasLength(1));

      await controller.retryUpload('block-0');

      // Two upload attempts, still exactly one article write.
      expect(repository.uploads, hasLength(2));
      expect(repository.createCalls, hasLength(1));
      expect(repository.updateCalls, isEmpty);
    },
  );

  test('reordering blocks changes the order sent to the backend', () async {
    final repository = _FakeRepository();
    final controller = _controller(repository)
      ..setTitle('Порядок')
      ..addBlock(ArticleBlockType.text)
      ..editBlockText('block-0', 'Первый')
      ..addBlock(ArticleBlockType.text)
      ..editBlockText('block-1', 'Второй')
      ..reorderBlocks(1, 0);

    await controller.save();

    expect(repository.createCalls.single.map((block) => block.textContent), [
      'Второй',
      'Первый',
    ]);
  });

  test('tags are capped and toggle off again', () {
    final controller = _controller(_FakeRepository());
    for (final tag in ['Природа', 'Море', 'История', 'Леса', 'Пешком']) {
      controller.toggleTag(tag);
    }
    expect(controller.state.tags, hasLength(ArticleLimits.maxTagsPerArticle));

    controller.toggleTag('Гастрономия');
    expect(
      controller.state.tags.contains('Гастрономия'),
      isFalse,
      reason: 'the sixth tag is refused',
    );

    controller.toggleTag('Море');
    expect(controller.state.tags.contains('Море'), isFalse);
  });

  test('submit is blocked until there is a title and real content', () async {
    final repository = _FakeRepository();
    final controller = _controller(repository);
    expect(controller.state.canSubmit, isFalse);

    controller.setTitle('Готовая статья');
    expect(controller.state.canSubmit, isFalse, reason: 'no blocks yet');

    controller
      ..addBlock(ArticleBlockType.text)
      ..editBlockText('block-0', 'Есть содержание');
    expect(controller.state.canSubmit, isTrue);

    await controller.submitForReview();
    expect(repository.submitted, isTrue);
    expect(controller.state.submitted, isTrue);
    expect(controller.state.status, ArticleStatus.pendingReview);
  });

  test('an existing draft is loaded into the editor', () async {
    final repository = _FakeRepository(
      existing: Article(
        id: 'article-9',
        title: 'Черновик',
        status: ArticleStatus.rejected,
        authorUserId: 'me',
        authorDisplayName: 'Вы',
        createdAt: DateTime.utc(2026, 9, 1),
        tags: const ['История'],
        blocks: const [
          ArticleBlock(
            id: 'b1',
            position: 0,
            blockType: ArticleBlockType.quote,
            textContent: 'Цитата',
            caption: 'Автор',
          ),
        ],
      ),
    );
    final controller = _controller(repository, articleId: 'article-9');
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.loading, isFalse);
    expect(controller.state.title, 'Черновик');
    expect(controller.state.tags, {'История'});
    expect(controller.state.blocks.single.type, ArticleBlockType.quote);
    expect(controller.state.blocks.single.caption, 'Автор');
    expect(controller.state.status, ArticleStatus.rejected);
  });

  test('autosave fires after the debounce, not on every keystroke', () async {
    final repository = _FakeRepository();
    final controller = _controller(repository)..setTitle('Ав');
    controller
      ..setTitle('Авто')
      ..setTitle('Автосейв');

    expect(repository.createCalls, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(repository.createCalls, hasLength(1));
  });
}

/// Editing a published article is allowed, but there is nothing to submit —
/// the backend re-queues it for moderation on the edit itself, and calling
/// submit on it answers 409 (2026-09-04).
void _publishedEditingTests() {
  Article _published() => Article(
    id: 'article-live',
    title: 'Уже опубликована',
    status: ArticleStatus.published,
    authorUserId: 'me',
    authorDisplayName: 'Вы',
    createdAt: DateTime.utc(2026, 9, 1),
    publishedAt: DateTime.utc(2026, 9, 2),
    blocks: const [
      ArticleBlock(
        id: 'b1',
        position: 0,
        blockType: ArticleBlockType.text,
        textContent: 'Текст',
      ),
    ],
  );

  test('a published article opens for editing but offers no submit', () async {
    final repository = _FakeRepository(existing: _published());
    final controller = _controller(repository, articleId: 'article-live');
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.title, 'Уже опубликована');
    expect(controller.state.status, ArticleStatus.published);
    expect(controller.state.canSubmitAtAll, isFalse);
    expect(controller.state.canSubmit, isFalse);
  });

  test('an article awaiting review offers no submit either', () async {
    final repository = _FakeRepository(
      existing: Article(
        id: 'article-queued',
        title: 'На проверке',
        status: ArticleStatus.pendingReview,
        authorUserId: 'me',
        authorDisplayName: 'Вы',
        createdAt: DateTime.utc(2026, 9, 1),
        blocks: const [
          ArticleBlock(
            id: 'b1',
            position: 0,
            blockType: ArticleBlockType.text,
            textContent: 'Текст',
          ),
        ],
      ),
    );
    final controller = _controller(repository, articleId: 'article-queued');
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.canSubmitAtAll, isFalse);
  });
}
