import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/features/articles/data/api_articles_repository.dart';
import 'package:tourism_mobile/features/articles/data/mock_articles_repository.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/domain/articles_repository.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';

final articlesRepositoryProvider = Provider<ArticlesRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return MockArticlesRepository();
  }
  return ApiArticlesRepository(ref.watch(dioProvider));
});

/// Published articles about a route — the "Статьи об этом маршруте" block.
final articlesForRouteProvider = FutureProvider.autoDispose
    .family<ArticleListPage, String>((ref, routeId) {
      return ref
          .watch(articlesRepositoryProvider)
          .listArticles(relatedRouteId: routeId);
    });

/// Published articles about a place.
final articlesForPlaceProvider = FutureProvider.autoDispose
    .family<ArticleListPage, String>((ref, placeId) {
      return ref
          .watch(articlesRepositoryProvider)
          .listArticles(relatedPlaceId: placeId);
    });

/// Published articles by a given author — the profile "Статьи" section.
final articlesByAuthorProvider = FutureProvider.autoDispose
    .family<ArticleListPage, String>((ref, authorUserId) {
      return ref
          .watch(articlesRepositoryProvider)
          .listArticles(authorUserId: authorUserId);
    });

/// "Мои статьи" — every status, own profile only.
final myArticlesProvider = FutureProvider.autoDispose<ArticleListPage>((
  ref,
) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return const ArticleListPage(items: [], total: 0);
  }
  return ref.watch(articlesRepositoryProvider).listMyArticles();
});

final articleDetailsProvider = FutureProvider.autoDispose
    .family<Article, String>((ref, articleId) {
      return ref.watch(articlesRepositoryProvider).getArticle(articleId);
    });

final articleCommentsProvider = FutureProvider.autoDispose
    .family<ArticleCommentPage, String>((ref, articleId) {
      return ref.watch(articlesRepositoryProvider).listComments(articleId);
    });

/// Saved-for-later articles — the "Статьи" section of the favorites screen.
final savedArticlesProvider = FutureProvider.autoDispose<ArticleListPage>((
  ref,
) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return const ArticleListPage(items: [], total: 0);
  }
  return ref.watch(articlesRepositoryProvider).listSaved();
});

/// "Читайте также" — published articles sharing at least one tag.
final articleRelatedProvider = FutureProvider.autoDispose
    .family<ArticleListPage, String>((ref, articleId) {
      return ref.watch(articlesRepositoryProvider).listRelated(articleId);
    });

/// Optimistic like overlay, keyed by article id — `null` means "trust the
/// article's own `likeCount`/`likedByMe`". Deliberately not an
/// `AsyncNotifier` + invalidate-refetch (that's the non-optimistic
/// profile-like pattern): a like should flip the instant it's tapped, and
/// this thin overlay is reverted on failure rather than round-tripping the
/// whole article again.
final articleLikeOverlayProvider = StateProvider.autoDispose
    .family<ArticleLikeStatus?, String>((ref, articleId) => null);

/// The same overlay trick for the bookmark toggle — `null` means "trust the
/// article's own `savedByMe`".
final articleSavedOverlayProvider = StateProvider.autoDispose
    .family<bool?, String>((ref, articleId) => null);
