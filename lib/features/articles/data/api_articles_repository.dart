import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/domain/articles_repository.dart';

final class ApiArticlesRepository implements ArticlesRepository {
  ApiArticlesRepository(this._dio);

  final Dio _dio;

  @override
  Future<ArticleListPage> listArticles({
    String? relatedRouteId,
    String? relatedPlaceId,
    String? authorUserId,
    String? query,
    int limit = 20,
    int offset = 0,
  }) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/articles',
        queryParameters: {
          'related_route_id': ?relatedRouteId,
          'related_place_id': ?relatedPlaceId,
          'author_user_id': ?authorUserId,
          'q': ?query,
          'limit': limit,
          'offset': offset,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return ArticleListPage.fromJson(data);
    });
  }

  @override
  Future<ArticleListPage> listMyArticles({int limit = 20, int offset = 0}) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/me/articles',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return ArticleListPage.fromJson(data);
    });
  }

  @override
  Future<Article> getArticle(String id) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/articles/$id',
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return Article.fromJson(data);
    });
  }

  @override
  Future<Article> createDraft({
    required String title,
    String? relatedRouteId,
    String? relatedPlaceId,
    List<String> tags = const [],
    List<ArticleBlockDraft> blocks = const [],
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/articles',
        data: _writePayload(
          title: title,
          relatedRouteId: relatedRouteId,
          relatedPlaceId: relatedPlaceId,
          tags: tags,
          blocks: blocks,
        ),
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return Article.fromJson(data);
    });
  }

  @override
  Future<Article> updateDraft(
    String id, {
    required String title,
    String? relatedRouteId,
    String? relatedPlaceId,
    List<String> tags = const [],
    List<ArticleBlockDraft> blocks = const [],
  }) {
    return guardApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/articles/$id',
        data: _writePayload(
          title: title,
          relatedRouteId: relatedRouteId,
          relatedPlaceId: relatedPlaceId,
          tags: tags,
          blocks: blocks,
        ),
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return Article.fromJson(data);
    });
  }

  @override
  Future<Article> submitForReview(String id) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/articles/$id/submit',
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return Article.fromJson(data);
    });
  }

  @override
  Future<void> deleteArticle(String id) {
    return guardApiCall(() async {
      await _dio.delete<void>('/api/v1/articles/$id');
    });
  }

  @override
  Future<ArticleBlock> uploadBlockImage(
    String articleId,
    String blockId,
    String filePath,
  ) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/articles/$articleId/blocks/$blockId/image',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(filePath),
        }),
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return ArticleBlock.fromJson(data);
    });
  }

  @override
  Future<void> deleteBlockImage(String articleId, String blockId) {
    return guardApiCall(() async {
      await _dio.delete<void>(
        '/api/v1/articles/$articleId/blocks/$blockId/image',
      );
    });
  }

  @override
  Future<ArticleCommentPage> listComments(
    String articleId, {
    int limit = 50,
    int offset = 0,
  }) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/articles/$articleId/comments',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return ArticleCommentPage.fromJson(data);
    });
  }

  @override
  Future<ArticleComment> createComment(
    String articleId,
    String body, {
    String? replyToCommentId,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/articles/$articleId/comments',
        data: {'body': body, 'reply_to_comment_id': ?replyToCommentId},
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return ArticleComment.fromJson(data);
    });
  }

  @override
  Future<void> deleteComment(String articleId, String commentId) {
    return guardApiCall(() async {
      await _dio.delete<void>(
        '/api/v1/articles/$articleId/comments/$commentId',
      );
    });
  }

  Map<String, Object?> _writePayload({
    required String title,
    required String? relatedRouteId,
    required String? relatedPlaceId,
    required List<String> tags,
    required List<ArticleBlockDraft> blocks,
  }) {
    return {
      'title': title,
      'related_route_id': relatedRouteId,
      'related_place_id': relatedPlaceId,
      'tags': tags,
      'blocks': blocks.map((block) => block.toJson()).toList(),
    };
  }

  @override
  Future<ArticleLikeStatus> setLike(String articleId, {required bool liked}) {
    return guardApiCall(() async {
      final response = liked
          ? await _dio.put<Map<String, dynamic>>(
              '/api/v1/articles/$articleId/like',
            )
          : await _dio.delete<Map<String, dynamic>>(
              '/api/v1/articles/$articleId/like',
            );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return ArticleLikeStatus.fromJson(data);
    });
  }

  @override
  Future<ArticleListPage> listRelated(String articleId) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/articles/$articleId/related',
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return ArticleListPage.fromJson(data);
    });
  }

  @override
  Future<bool> setSaved(String articleId, {required bool saved}) {
    return guardApiCall(() async {
      final response = saved
          ? await _dio.put<Map<String, dynamic>>(
              '/api/v1/articles/$articleId/save',
            )
          : await _dio.delete<Map<String, dynamic>>(
              '/api/v1/articles/$articleId/save',
            );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return data['saved_by_me'] as bool? ?? saved;
    });
  }

  @override
  Future<ArticleListPage> listSaved({int limit = 20, int offset = 0}) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/me/saved-articles',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return ArticleListPage.fromJson(data);
    });
  }
}
