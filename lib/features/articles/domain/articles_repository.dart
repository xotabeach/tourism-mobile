import 'package:tourism_mobile/features/articles/domain/article.dart';

/// Backend limits (`content/infrastructure/models.py`) — client-side checks
/// against these prevent the 400/409/429 cases instead of just catching them.
abstract final class ArticleLimits {
  static const maxTitleLength = 120;
  static const maxTextBlockLength = 4000;
  static const maxCommentLength = 2000;
  static const maxBlocksPerArticle = 20;
  static const maxImagesPerArticle = 12;
  static const maxTagsPerArticle = 5;
  static const maxListItems = 15;
  static const maxListItemLength = 200;
  static const maxQuoteCaptionLength = 80;

  /// `article_service.py`: `_SUBMIT_WINDOW` / `_MAX_SUBMISSIONS_PER_WINDOW`.
  static const maxSubmissionsPerWindow = 3;

  /// `article_comment_service.py`: delete window for one's own comment.
  static const commentDeleteWindow = Duration(hours: 6);
}

abstract interface class ArticlesRepository {
  Future<ArticleListPage> listArticles({
    String? relatedRouteId,
    String? relatedPlaceId,
    String? authorUserId,
    String? query,
    int limit = 20,
    int offset = 0,
  });

  Future<ArticleListPage> listMyArticles({int limit = 20, int offset = 0});

  Future<Article> getArticle(String id);

  Future<Article> createDraft({
    required String title,
    String? relatedRouteId,
    String? relatedPlaceId,
    List<String> tags = const [],
    List<ArticleBlockDraft> blocks = const [],
  });

  Future<Article> updateDraft(
    String id, {
    required String title,
    String? relatedRouteId,
    String? relatedPlaceId,
    List<String> tags = const [],
    List<ArticleBlockDraft> blocks = const [],
  });

  Future<Article> submitForReview(String id);

  Future<void> deleteArticle(String id);

  Future<ArticleBlock> uploadBlockImage(
    String articleId,
    String blockId,
    String filePath,
  );

  Future<void> deleteBlockImage(String articleId, String blockId);

  Future<ArticleCommentPage> listComments(
    String articleId, {
    int limit = 50,
    int offset = 0,
  });

  Future<ArticleComment> createComment(
    String articleId,
    String body, {
    String? replyToCommentId,
  });

  Future<void> deleteComment(String articleId, String commentId);

  Future<ArticleLikeStatus> setLike(String articleId, {required bool liked});

  Future<ArticleListPage> listRelated(String articleId);

  /// Private reading list — the "Статьи" section of the favorites screen.
  Future<bool> setSaved(String articleId, {required bool saved});

  Future<ArticleListPage> listSaved({int limit = 20, int offset = 0});
}
