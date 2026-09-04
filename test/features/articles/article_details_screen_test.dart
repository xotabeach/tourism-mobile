import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/domain/articles_repository.dart';
import 'package:tourism_mobile/features/articles/presentation/article_details_screen.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/tag_chip_picker.dart';

import '../../support/test_overrides.dart';

const _ownerId = 'mock-user';

class _FakeArticlesRepository implements ArticlesRepository {
  _FakeArticlesRepository({
    required this.article,
    this.comments = const [],
    this.related = const [],
    this.onSetLike,
  });

  final Article article;
  final List<ArticleComment> comments;
  final List<ArticleSummary> related;
  final Future<ArticleLikeStatus> Function({required bool liked})? onSetLike;

  @override
  Future<Article> getArticle(String id) async => article;

  @override
  Future<ArticleCommentPage> listComments(
    String articleId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return ArticleCommentPage(items: comments, total: comments.length);
  }

  @override
  Future<void> deleteComment(String articleId, String commentId) async {}

  @override
  Future<ArticleListPage> listRelated(String articleId) async {
    return ArticleListPage(items: related, total: related.length);
  }

  @override
  Future<ArticleLikeStatus> setLike(String articleId, {required bool liked}) {
    final handler = onSetLike;
    if (handler == null) {
      throw UnimplementedError('setLike is not used in this test');
    }
    return handler(liked: liked);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

Article _articleWith({
  ArticleStatus status = ArticleStatus.published,
  String authorUserId = 'someone-else',
  List<ArticleBlock> blocks = const [],
  List<String> tags = const [],
  int likeCount = 0,
  bool likedByMe = false,
  int viewCount = 0,
  int readingTimeMinutes = 1,
}) {
  return Article(
    id: 'article-1',
    title: 'Тестовая статья',
    status: status,
    authorUserId: authorUserId,
    authorDisplayName: 'Автор',
    createdAt: DateTime.utc(2026, 8, 1),
    publishedAt: DateTime.utc(2026, 8, 2),
    blocks: blocks,
    tags: tags,
    likeCount: likeCount,
    likedByMe: likedByMe,
    viewCount: viewCount,
    readingTimeMinutes: readingTimeMinutes,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Article article,
  List<ArticleComment> comments = const [],
  List<ArticleSummary> related = const [],
  Future<ArticleLikeStatus> Function({required bool liked})? onSetLike,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testSessionOverrides(onboardingCompleted: true),
        articlesRepositoryProvider.overrideWithValue(
          _FakeArticlesRepository(
            article: article,
            comments: comments,
            related: related,
            onSetLike: onSetLike,
          ),
        ),
      ],
      child: MaterialApp(home: ArticleDetailsScreen(articleId: article.id)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  _designPassTests();
  group('ArticleDetailsScreen blocks', () {
    testWidgets('renders blocks in position order, not list order', (
      tester,
    ) async {
      final article = _articleWith(
        blocks: const [
          ArticleBlock(
            id: 'b2',
            position: 1,
            blockType: ArticleBlockType.text,
            textContent: 'Второй блок текста',
          ),
          ArticleBlock(
            id: 'b1',
            position: 0,
            blockType: ArticleBlockType.text,
            textContent: 'Первый блок текста',
          ),
        ],
      );
      await _pump(tester, article: article);

      final firstOffset = tester.getTopLeft(find.text('Первый блок текста'));
      final secondOffset = tester.getTopLeft(find.text('Второй блок текста'));
      expect(firstOffset.dy, lessThan(secondOffset.dy));
    });

    testWidgets('reserves an image block\'s aspect ratio before it loads', (
      tester,
    ) async {
      final article = _articleWith(
        blocks: const [
          ArticleBlock(
            id: 'b1',
            position: 0,
            blockType: ArticleBlockType.image,
            imageUrl: 'assets/images/coast-pine-twilight.jpg',
            imageWidth: 1600,
            imageHeight: 800,
          ),
        ],
      );
      await _pump(tester, article: article);

      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatio.aspectRatio, 1600 / 800);
    });

    testWidgets('an image block with no uploaded file renders nothing', (
      tester,
    ) async {
      final article = _articleWith(
        blocks: const [
          ArticleBlock(
            id: 'b1',
            position: 0,
            blockType: ArticleBlockType.image,
          ),
        ],
      );
      await _pump(tester, article: article);

      expect(find.byType(AspectRatio), findsNothing);
    });
  });

  group('ArticleDetailsScreen owner status banner', () {
    testWidgets('shows a status badge for the author\'s own draft', (
      tester,
    ) async {
      final article = _articleWith(
        status: ArticleStatus.draft,
        authorUserId: _ownerId,
      );
      await _pump(tester, article: article);

      expect(
        find.byKey(const ValueKey('article-owner-status')),
        findsOneWidget,
      );
      expect(find.text('Черновик'), findsOneWidget);
    });

    testWidgets('warns the author that editing a live article re-queues it', (
      tester,
    ) async {
      // Editing a published article is allowed, but it goes back through
      // moderation — otherwise the review could be walked around by
      // replacing the text after approval. The author has to know that
      // before they tap Редактировать (2026-09-04).
      final article = _articleWith(
        status: ArticleStatus.published,
        authorUserId: _ownerId,
      );
      await _pump(tester, article: article);

      expect(find.byKey(const ValueKey('article-owner-status')), findsOneWidget);
      expect(find.textContaining('повторную проверку'), findsOneWidget);
      expect(find.text('Редактировать'), findsOneWidget);
    });

    testWidgets('shows nothing to a viewer who is not the author', (
      tester,
    ) async {
      final article = _articleWith(
        status: ArticleStatus.draft,
        authorUserId: 'someone-else',
      );
      await _pump(tester, article: article);

      expect(find.byKey(const ValueKey('article-owner-status')), findsNothing);
    });
  });

  group('ArticleDetailsScreen comments', () {
    testWidgets('badges the viewer\'s own pending comment as "На проверке"', (
      tester,
    ) async {
      final article = _articleWith();
      final comments = [
        ArticleComment(
          id: 'c1',
          articleId: article.id,
          authorUserId: _ownerId,
          authorDisplayName: 'Вы',
          body: 'Ждёт модерации',
          status: ArticleCommentStatus.pendingReview,
          createdAt: DateTime.now().toUtc(),
        ),
      ];
      await _pump(tester, article: article, comments: comments);

      expect(
        find.byKey(const ValueKey('article-comment-pending-badge')),
        findsOneWidget,
      );
    });

    testWidgets('a comment shows the author rank and folds a long body', (
      tester,
    ) async {
      final article = _articleWith();
      final comments = [
        ArticleComment(
          id: 'c1',
          articleId: article.id,
          authorUserId: 'other-user',
          authorDisplayName: 'Никита',
          authorRankTitle: 'Продвинутый пешеход',
          body:
              'По-моему скромному мнению, если смотреть через призму моего '
              'пешеходного опыта, маршрут не достаточно интересен с точки '
              'зрения сложности, не смотря на третий уровень. В остальном '
              'новичкам подойдёт: набережная, канатка и один переезд между '
              'посёлками, всё размечено и понятно даже без карты.',
          status: ArticleCommentStatus.published,
          createdAt: DateTime.now().toUtc(),
        ),
      ];
      await _pump(tester, article: article, comments: comments);

      // Ранг под именем и «Читать полностью» — со скрина «Страница блога».
      expect(find.text('Продвинутый пешеход'), findsOneWidget);
      final expand = find.byKey(const ValueKey('article-comment-expand'));
      expect(expand, findsOneWidget);
      expect(find.text('Читать полностью'), findsOneWidget);

      await tester.ensureVisible(expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      expect(find.text('Свернуть'), findsOneWidget);
    });

    testWidgets('a short comment gets no "Читать полностью"', (tester) async {
      final article = _articleWith();
      final comments = [
        ArticleComment(
          id: 'c1',
          articleId: article.id,
          authorUserId: 'other-user',
          authorDisplayName: 'Мария',
          body: 'Отличный маршрут!',
          status: ArticleCommentStatus.published,
          createdAt: DateTime.now().toUtc(),
        ),
      ];
      await _pump(tester, article: article, comments: comments);

      expect(find.text('Читать полностью'), findsNothing);
    });

    testWidgets('indents a reply under its parent comment', (tester) async {
      final article = _articleWith();
      final now = DateTime.now().toUtc();
      final comments = [
        ArticleComment(
          id: 'root',
          articleId: article.id,
          authorUserId: 'other-user',
          authorDisplayName: 'Автор корня',
          body: 'Корневой комментарий',
          status: ArticleCommentStatus.published,
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        ArticleComment(
          id: 'reply',
          articleId: article.id,
          authorUserId: 'other-user-2',
          authorDisplayName: 'Автор ответа',
          body: 'Ответ на комментарий',
          status: ArticleCommentStatus.published,
          replyToCommentId: 'root',
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
      ];
      await _pump(tester, article: article, comments: comments);

      final replyTile = find.byKey(const ValueKey('article-comment-reply'));
      final padding = tester.widget<Padding>(
        find.ancestor(of: replyTile, matching: find.byType(Padding)).first,
      );
      expect((padding.padding as EdgeInsets).left, 28);
    });

    testWidgets('lets the author delete their own comment within 6 hours', (
      tester,
    ) async {
      final article = _articleWith();
      final comments = [
        ArticleComment(
          id: 'recent',
          articleId: article.id,
          authorUserId: _ownerId,
          authorDisplayName: 'Вы',
          body: 'Написано только что',
          status: ArticleCommentStatus.published,
          createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 5)),
        ),
      ];
      await _pump(tester, article: article, comments: comments);

      expect(find.text('Удалить'), findsOneWidget);
    });

    testWidgets('hides delete for the author\'s own comment past 6 hours', (
      tester,
    ) async {
      final article = _articleWith();
      final comments = [
        ArticleComment(
          id: 'old',
          articleId: article.id,
          authorUserId: _ownerId,
          authorDisplayName: 'Вы',
          body: 'Написано давно',
          status: ArticleCommentStatus.published,
          createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 7)),
        ),
      ];
      await _pump(tester, article: article, comments: comments);

      expect(find.text('Удалить'), findsNothing);
    });

    testWidgets('never shows delete for someone else\'s comment', (
      tester,
    ) async {
      final article = _articleWith();
      final comments = [
        ArticleComment(
          id: 'someone-elses',
          articleId: article.id,
          authorUserId: 'not-the-viewer',
          authorDisplayName: 'Другой автор',
          body: 'Чужой комментарий',
          status: ArticleCommentStatus.published,
          createdAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 5),
          ),
        ),
      ];
      await _pump(tester, article: article, comments: comments);

      expect(find.text('Удалить'), findsNothing);
    });
  });

  group('ArticleDetailsScreen v2 blocks', () {
    testWidgets('renders a quote block with its caption', (tester) async {
      final article = _articleWith(
        blocks: const [
          ArticleBlock(
            id: 'b1',
            position: 0,
            blockType: ArticleBlockType.quote,
            textContent: 'Цитата дня',
            caption: 'Автор цитаты',
          ),
        ],
      );
      await _pump(tester, article: article);

      expect(find.text('Цитата дня'), findsOneWidget);
      expect(find.text('— Автор цитаты'), findsOneWidget);
    });

    testWidgets('renders a bulleted list block, one line per item', (
      tester,
    ) async {
      final article = _articleWith(
        blocks: const [
          ArticleBlock(
            id: 'b1',
            position: 0,
            blockType: ArticleBlockType.list,
            textContent: 'Первый\nВторой\nТретий',
            listStyle: ListStyle.bullet,
          ),
        ],
      );
      await _pump(tester, article: article);

      expect(find.text('Первый'), findsOneWidget);
      expect(find.text('Второй'), findsOneWidget);
      expect(find.text('Третий'), findsOneWidget);
    });

    testWidgets('renders a numbered list with visible numerals', (
      tester,
    ) async {
      final article = _articleWith(
        blocks: const [
          ArticleBlock(
            id: 'b1',
            position: 0,
            blockType: ArticleBlockType.list,
            textContent: 'Раз\nДва',
            listStyle: ListStyle.numbered,
          ),
        ],
      );
      await _pump(tester, article: article);

      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
    });

    testWidgets('renders a divider block', (tester) async {
      final article = _articleWith(
        blocks: const [
          ArticleBlock(
            id: 'b1',
            position: 0,
            blockType: ArticleBlockType.divider,
          ),
        ],
      );
      await _pump(tester, article: article);

      expect(
        find.byKey(const ValueKey('article-divider-block')),
        findsOneWidget,
      );
    });
  });

  group('ArticleDetailsScreen tags', () {
    testWidgets('shows a chip for every tag', (tester) async {
      final article = _articleWith(tags: const ['История', 'Пешком']);
      await _pump(tester, article: article);

      expect(find.text('История'), findsOneWidget);
      expect(find.text('Пешком'), findsOneWidget);
    });

    testWidgets('shows no tag row when the article has none', (tester) async {
      final article = _articleWith();
      await _pump(tester, article: article);

      expect(find.byType(TagChipPicker), findsNothing);
    });
  });

  group('ArticleDetailsScreen reactions', () {
    testWidgets('shows the like count and view count', (tester) async {
      final article = _articleWith(likeCount: 12, viewCount: 340);
      await _pump(tester, article: article);

      expect(find.text('12'), findsOneWidget);
      expect(find.text('340'), findsOneWidget);
    });

    testWidgets('tapping like flips the heart instantly (optimistic)', (
      tester,
    ) async {
      final article = _articleWith(likeCount: 5, likedByMe: false);
      final completer = Completer<ArticleLikeStatus>();
      await _pump(
        tester,
        article: article,
        onSetLike: ({required liked}) => completer.future,
      );

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pump();

      // Optimistic: the count already moved before the fake network call
      // resolves.
      expect(find.text('6'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      completer.complete(
        const ArticleLikeStatus(likeCount: 6, likedByMe: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('a failed like reverts the optimistic count', (tester) async {
      final article = _articleWith(likeCount: 5, likedByMe: false);
      await _pump(
        tester,
        article: article,
        onSetLike: ({required liked}) async {
          throw const NetworkFailure();
        },
      );

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    });
  });

  group('ArticleDetailsScreen related articles', () {
    testWidgets('shows a "Читайте также" row when related articles exist', (
      tester,
    ) async {
      final article = _articleWith(tags: const ['История']);
      final related = [
        ArticleSummary(
          id: 'article-2',
          title: 'Похожая статья',
          status: ArticleStatus.published,
          authorUserId: 'other',
          authorDisplayName: 'Другой автор',
          createdAt: DateTime.utc(2026, 7, 1),
        ),
      ];
      await _pump(tester, article: article, related: related);

      expect(find.text('Читайте также'), findsOneWidget);
      expect(find.text('Похожая статья'), findsOneWidget);
    });

    testWidgets('hides the section when there are no related articles', (
      tester,
    ) async {
      final article = _articleWith();
      await _pump(tester, article: article);

      expect(find.text('Читайте также'), findsNothing);
    });
  });
}

/// Верстка по макету дизайнера (КрымТрип-8, 2026-09-04).
void _designPassTests() {
  testWidgets('the header carries the wordmark, not the article title', (
    tester,
  ) async {
    final article = _articleWith(status: ArticleStatus.published);
    await _pump(tester, article: article);

    expect(find.text('КРЫМТРИП'), findsOneWidget);
    // Заголовок статьи живёт в теле и ровно в одном месте.
    expect(find.text(article.title), findsOneWidget);
  });

  testWidgets('the author and reactions come before the title', (
    tester,
  ) async {
    // Порядок с макета: сначала «кто и когда», потом реакции, затем «о чём».
    final article = _articleWith(status: ArticleStatus.published);
    await _pump(tester, article: article);

    final authorY = tester.getTopLeft(find.text(article.authorDisplayName)).dy;
    final titleY = tester.getTopLeft(find.text(article.title)).dy;
    expect(authorY, lessThan(titleY));
  });

  testWidgets('only the author is offered the edit button', (tester) async {
    await _pump(
      tester,
      article: _articleWith(
        status: ArticleStatus.published,
        authorUserId: _ownerId,
      ),
    );
    expect(find.bySemanticsLabel('Редактировать статью'), findsOneWidget);

    await _pump(
      tester,
      article: _articleWith(
        status: ArticleStatus.published,
        authorUserId: 'somebody-else',
      ),
    );
    expect(find.bySemanticsLabel('Редактировать статью'), findsNothing);
  });
}
