import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_list_skeleton.dart';
import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/article_card.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

enum UserContentKind { routes, articles }

/// Every published route of a user (the profile carousel shows up to 20).
final AutoDisposeFutureProviderFamily<List<RouteSummary>, String>
userAllRoutesProvider = FutureProvider.autoDispose
    .family<List<RouteSummary>, String>((ref, userId) {
      return ref.watch(publicProfileRepositoryProvider).userRoutes(userId);
    });

/// Every published article of a user, as many as one request allows.
final AutoDisposeFutureProviderFamily<ArticleListPage, String>
userAllArticlesProvider = FutureProvider.autoDispose
    .family<ArticleListPage, String>((ref, userId) {
      return ref
          .watch(articlesRepositoryProvider)
          .listArticles(authorUserId: userId, limit: 50);
    });

/// «Все маршруты» / «Все статьи» of someone else's profile, opened from the
/// last card of the profile carousel.
class UserContentListScreen extends ConsumerWidget {
  const UserContentListScreen({
    required this.userId,
    required this.kind,
    this.initialRoutes = const [],
    super.key,
  });

  final String userId;
  final UserContentKind kind;

  /// What the profile already has, shown in mock builds (no API behind them).
  final List<RouteSummary> initialRoutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mock = ref.watch(appConfigProvider).useMockData;
    return switch (kind) {
      UserContentKind.routes => _list(
        context,
        ref,
        title: 'Все маршруты',
        async: mock
            ? AsyncValue.data(initialRoutes)
            : ref.watch(userAllRoutesProvider(userId)),
        retry: () => ref.invalidate(userAllRoutesProvider(userId)),
        empty: 'У путешественника пока нет маршрутов',
        itemBuilder: (route) => RouteHeroCard(route: route, height: 304),
      ),
      UserContentKind.articles => _list(
        context,
        ref,
        title: 'Все статьи',
        async: ref
            .watch(userAllArticlesProvider(userId))
            .whenData((page) => page.items),
        retry: () => ref.invalidate(userAllArticlesProvider(userId)),
        empty: 'У путешественника пока нет статей',
        itemBuilder: (article) => ArticleCard(article: article),
      ),
    };
  }

  Widget _list<T>(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required AsyncValue<List<T>> async,
    required VoidCallback retry,
    required String empty,
    required Widget Function(T item) itemBuilder,
  }) {
    final items = async.valueOrNull;
    return SettingsScaffold(
      barTitle: items == null ? title : '$title (${items.length})',
      children: [
        async.when(
          skipLoadingOnRefresh: true,
          loading: () => const AppListSkeleton(rows: 3),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Не удалось загрузить',
                style: AppTypography.settingsRowSubtitle,
              ),
              TextButton(onPressed: retry, child: const Text('Повторить')),
            ],
          ),
          data: (list) => list.isEmpty
              ? Text(empty, style: AppTypography.settingsRowSubtitle)
              : Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      itemBuilder(list[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
