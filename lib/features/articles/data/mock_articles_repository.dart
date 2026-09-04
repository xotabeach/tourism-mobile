import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/domain/articles_repository.dart';

/// `DATA_SOURCE=mock` backing for local development without a backend.
final class MockArticlesRepository implements ArticlesRepository {
  final _articles = <String, Article>{
    'mock-article-1': Article(
      id: 'mock-article-1',
      title: 'Три дня на Южном берегу без машины',
      status: ArticleStatus.published,
      authorUserId: 'mock-author-1',
      authorDisplayName: 'Никита',
      authorRankTitle: 'Продвинутый пешеход',
      createdAt: DateTime.utc(2026, 8, 20),
      publishedAt: DateTime.utc(2026, 8, 21),
      relatedRouteId: 'mock-route-1',
      tags: const ['История', 'Личный опыт'],
      excerpt:
          'Маршрут занял три полных дня, электричек и автобусов было '
          'больше, чем ожидалось, но вид с канатки того стоил.',
      readingTimeMinutes: 4,
      likeCount: 18,
      viewCount: 214,
      blocks: const [
        ArticleBlock(
          id: 'block-1',
          position: 0,
          blockType: ArticleBlockType.text,
          textContent:
              'Маршрут занял три полных дня, электричек и автобусов было '
              'больше, чем ожидалось, но вид с канатки того стоил.',
        ),
        ArticleBlock(
          id: 'block-2',
          position: 1,
          blockType: ArticleBlockType.image,
          imageUrl: 'assets/images/coast-pine-twilight.jpg',
          imageWidth: 1600,
          imageHeight: 1200,
        ),
        ArticleBlock(
          id: 'block-3',
          position: 2,
          blockType: ArticleBlockType.quote,
          textContent:
              'Если ехать без машины — закладывайте на полчаса больше на '
              'любой переход, автобусы в сезон переполнены.',
          caption: 'из разговора с местным гидом',
        ),
        ArticleBlock(
          id: 'block-4',
          position: 3,
          blockType: ArticleBlockType.list,
          textContent:
              'Канатная дорога «Мисхор — Ай-Петри» — ехать до 10:00\n'
              'Обед в Мисхоре — кафе у нижней станции\n'
              'Возврат автобусом №5 — последний рейс в 19:40',
          listStyle: ListStyle.bullet,
        ),
      ],
    ),
    'mock-article-2': Article(
      id: 'mock-article-2',
      title: 'Где поесть у моря дёшево: 7 мест в Алуште',
      status: ArticleStatus.published,
      authorUserId: 'mock-author-2',
      authorDisplayName: 'Мария',
      authorRankTitle: 'Опытный турист',
      createdAt: DateTime.utc(2026, 8, 10),
      publishedAt: DateTime.utc(2026, 8, 11),
      tags: const ['Гастрономия', 'Бюджетно', 'Личный опыт'],
      excerpt:
          'Собрала места, где обед на двоих обходится дешевле тысячи — '
          'с ценами и адресами.',
      readingTimeMinutes: 6,
      likeCount: 2400,
      viewCount: 5100,
      blocks: const [
        ArticleBlock(
          id: 'block-5',
          position: 0,
          blockType: ArticleBlockType.text,
          textContent:
              'Собрала места, где обед на двоих обходится дешевле тысячи — '
              'с ценами и адресами.',
        ),
      ],
    ),
  };

  final _comments = <String, List<ArticleComment>>{
    'mock-article-1': [
      ArticleComment(
        id: 'comment-1',
        articleId: 'mock-article-1',
        authorUserId: 'mock-author-2',
        authorDisplayName: 'Мария',
        body: 'Отличный маршрут, повторили в июле!',
        status: ArticleCommentStatus.published,
        createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      ),
    ],
  };

  @override
  Future<ArticleListPage> listArticles({
    String? relatedRouteId,
    String? relatedPlaceId,
    String? authorUserId,
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    final needle = query?.trim().toLowerCase();
    final items = _articles.values
        .where((article) => article.status == ArticleStatus.published)
        .where(
          (article) =>
              needle == null ||
              needle.isEmpty ||
              article.title.toLowerCase().contains(needle) ||
              article.tags.any((tag) => tag.toLowerCase().contains(needle)),
        )
        .where(
          (article) =>
              relatedRouteId == null ||
              article.relatedRouteId == relatedRouteId,
        )
        .where(
          (article) =>
              relatedPlaceId == null ||
              article.relatedPlaceId == relatedPlaceId,
        )
        .where(
          (article) =>
              authorUserId == null || article.authorUserId == authorUserId,
        )
        .map(_asSummary)
        .toList();
    return ArticleListPage(items: items, total: items.length);
  }

  @override
  Future<ArticleListPage> listMyArticles({
    int limit = 20,
    int offset = 0,
  }) async {
    final items = _articles.values.map(_asSummary).toList();
    return ArticleListPage(items: items, total: items.length);
  }

  @override
  Future<Article> getArticle(String id) async {
    final article = _articles[id];
    if (article == null) {
      throw StateError('mock article $id not found');
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
    final id = 'mock-article-${_articles.length + 1}';
    final article = Article(
      id: id,
      title: title,
      status: ArticleStatus.draft,
      authorUserId: 'mock-user',
      authorDisplayName: 'Вы',
      createdAt: DateTime.now().toUtc(),
      relatedRouteId: relatedRouteId,
      relatedPlaceId: relatedPlaceId,
      tags: tags,
      blocks: _draftsToBlocks(blocks),
    );
    _articles[id] = article;
    return article;
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
    final existing = _articles[id];
    if (existing == null) {
      throw StateError('mock article $id not found');
    }
    final updated = Article(
      id: existing.id,
      title: title,
      status: existing.status,
      authorUserId: existing.authorUserId,
      authorDisplayName: existing.authorDisplayName,
      authorAvatarUrl: existing.authorAvatarUrl,
      createdAt: existing.createdAt,
      publishedAt: existing.publishedAt,
      relatedRouteId: relatedRouteId,
      relatedPlaceId: relatedPlaceId,
      coverImageUrl: existing.coverImageUrl,
      moderatorNote: existing.moderatorNote,
      tags: tags,
      likeCount: existing.likeCount,
      likedByMe: existing.likedByMe,
      viewCount: existing.viewCount,
      isFeatured: existing.isFeatured,
      blocks: _draftsToBlocks(blocks),
    );
    _articles[id] = updated;
    return updated;
  }

  @override
  Future<Article> submitForReview(String id) async {
    final existing = _articles[id];
    if (existing == null) {
      throw StateError('mock article $id not found');
    }
    final updated = Article(
      id: existing.id,
      title: existing.title,
      status: ArticleStatus.pendingReview,
      authorUserId: existing.authorUserId,
      authorDisplayName: existing.authorDisplayName,
      authorAvatarUrl: existing.authorAvatarUrl,
      createdAt: existing.createdAt,
      relatedRouteId: existing.relatedRouteId,
      relatedPlaceId: existing.relatedPlaceId,
      coverImageUrl: existing.coverImageUrl,
      tags: existing.tags,
      likeCount: existing.likeCount,
      likedByMe: existing.likedByMe,
      viewCount: existing.viewCount,
      isFeatured: existing.isFeatured,
      blocks: existing.blocks,
    );
    _articles[id] = updated;
    return updated;
  }

  @override
  Future<void> deleteArticle(String id) async {
    _articles.remove(id);
  }

  @override
  Future<ArticleBlock> uploadBlockImage(
    String articleId,
    String blockId,
    String filePath,
  ) async {
    final article = _articles[articleId];
    if (article == null) {
      throw StateError('mock article $articleId not found');
    }
    final updatedBlocks = [
      for (final block in article.blocks)
        if (block.id == blockId)
          block.copyWith(
            imageUrl: filePath,
            imageWidth: 1600,
            imageHeight: 1200,
          )
        else
          block,
    ];
    _articles[articleId] = Article(
      id: article.id,
      title: article.title,
      status: article.status,
      authorUserId: article.authorUserId,
      authorDisplayName: article.authorDisplayName,
      authorAvatarUrl: article.authorAvatarUrl,
      authorRankTitle: article.authorRankTitle,
      createdAt: article.createdAt,
      publishedAt: article.publishedAt,
      relatedRouteId: article.relatedRouteId,
      relatedPlaceId: article.relatedPlaceId,
      coverImageUrl: article.coverImageUrl,
      tags: article.tags,
      likeCount: article.likeCount,
      likedByMe: article.likedByMe,
      viewCount: article.viewCount,
      isFeatured: article.isFeatured,
      blocks: updatedBlocks,
    );
    return updatedBlocks.firstWhere((block) => block.id == blockId);
  }

  @override
  Future<void> deleteBlockImage(String articleId, String blockId) async {
    final article = _articles[articleId];
    if (article == null) {
      return;
    }
    final updatedBlocks = [
      for (final block in article.blocks)
        if (block.id == blockId) block.copyWith(clearImageUrl: true) else block,
    ];
    _articles[articleId] = Article(
      id: article.id,
      title: article.title,
      status: article.status,
      authorUserId: article.authorUserId,
      authorDisplayName: article.authorDisplayName,
      authorAvatarUrl: article.authorAvatarUrl,
      authorRankTitle: article.authorRankTitle,
      createdAt: article.createdAt,
      publishedAt: article.publishedAt,
      relatedRouteId: article.relatedRouteId,
      relatedPlaceId: article.relatedPlaceId,
      coverImageUrl: article.coverImageUrl,
      tags: article.tags,
      likeCount: article.likeCount,
      likedByMe: article.likedByMe,
      viewCount: article.viewCount,
      isFeatured: article.isFeatured,
      blocks: updatedBlocks,
    );
  }

  @override
  Future<ArticleCommentPage> listComments(
    String articleId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final items = _comments[articleId] ?? const [];
    return ArticleCommentPage(items: items, total: items.length);
  }

  @override
  Future<ArticleComment> createComment(
    String articleId,
    String body, {
    String? replyToCommentId,
  }) async {
    final comment = ArticleComment(
      id: 'mock-comment-${DateTime.now().microsecondsSinceEpoch}',
      articleId: articleId,
      authorUserId: 'mock-user',
      authorDisplayName: 'Вы',
      body: body,
      status: ArticleCommentStatus.pendingReview,
      replyToCommentId: replyToCommentId,
      createdAt: DateTime.now().toUtc(),
    );
    _comments.putIfAbsent(articleId, () => []).add(comment);
    return comment;
  }

  @override
  Future<void> deleteComment(String articleId, String commentId) async {
    _comments[articleId]?.removeWhere((comment) => comment.id == commentId);
  }

  ArticleSummary _asSummary(Article article) {
    return ArticleSummary(
      id: article.id,
      title: article.title,
      status: article.status,
      authorUserId: article.authorUserId,
      authorDisplayName: article.authorDisplayName,
      authorAvatarUrl: article.authorAvatarUrl,
      authorRankTitle: article.authorRankTitle,
      relatedRouteId: article.relatedRouteId,
      relatedPlaceId: article.relatedPlaceId,
      coverImageUrl: article.coverImageUrl,
      createdAt: article.createdAt,
      publishedAt: article.publishedAt,
      tags: article.tags,
      excerpt: article.excerpt,
      readingTimeMinutes: article.readingTimeMinutes,
      likeCount: article.likeCount,
      likedByMe: article.likedByMe,
      viewCount: article.viewCount,
      isFeatured: article.isFeatured,
    );
  }

  List<ArticleBlock> _draftsToBlocks(List<ArticleBlockDraft> drafts) {
    return [
      for (var index = 0; index < drafts.length; index++)
        ArticleBlock(
          id: drafts[index].id ?? 'mock-block-$index',
          position: index,
          blockType: drafts[index].blockType,
          textContent: drafts[index].textContent,
          caption: drafts[index].caption,
          listStyle: drafts[index].listStyle,
        ),
    ];
  }

  @override
  Future<ArticleLikeStatus> setLike(
    String articleId, {
    required bool liked,
  }) async {
    final article = _articles[articleId];
    if (article == null) {
      throw StateError('mock article $articleId not found');
    }
    if (article.likedByMe == liked) {
      return ArticleLikeStatus(likeCount: article.likeCount, likedByMe: liked);
    }
    final likeCount = liked ? article.likeCount + 1 : article.likeCount - 1;
    _articles[articleId] = article.copyWithLike(
      likeCount: likeCount,
      likedByMe: liked,
    );
    return ArticleLikeStatus(likeCount: likeCount, likedByMe: liked);
  }

  final _saved = <String>{};

  @override
  Future<bool> setSaved(String articleId, {required bool saved}) async {
    if (saved) {
      _saved.add(articleId);
    } else {
      _saved.remove(articleId);
    }
    return saved;
  }

  @override
  Future<ArticleListPage> listSaved({int limit = 20, int offset = 0}) async {
    final items = _articles.values
        .where((article) => _saved.contains(article.id))
        .map(_asSummary)
        .toList();
    return ArticleListPage(items: items, total: items.length);
  }

  @override
  Future<ArticleListPage> listRelated(String articleId) async {
    final article = _articles[articleId];
    if (article == null || article.tags.isEmpty) {
      return const ArticleListPage(items: [], total: 0);
    }
    final items = _articles.values
        .where((other) => other.id != articleId)
        .where((other) => other.tags.any(article.tags.contains))
        .map(_asSummary)
        .toList();
    return ArticleListPage(items: items, total: items.length);
  }
}
