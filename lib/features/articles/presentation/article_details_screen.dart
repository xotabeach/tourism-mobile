import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/presentation/article_comments_section.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/article_block_view.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/article_card.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/tag_chip_picker.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class ArticleDetailsScreen extends ConsumerWidget {
  const ArticleDetailsScreen({required this.articleId, super.key});

  static const routePath = '/articles/:id';

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articleAsync = ref.watch(articleDetailsProvider(articleId));
    final selfUserId = ref.watch(sessionProvider).userId;
    final article = articleAsync.valueOrNull;
    final canEdit =
        article != null &&
        selfUserId != null &&
        selfUserId == article.authorUserId &&
        article.status != ArticleStatus.deleted;

    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      appBar: AppBar(
        backgroundColor: AppColors.pageSurface,
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        // Вордмарк вместо заголовка и круглые кнопки по краям — по макету
        // дизайнера (КрымТрип-8). Во время загрузки под вордмарком пусто,
        // и без него экран со скелетом читался как серый прямоугольник.
        title: const _HeaderWordmark(),
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _RoundHeaderButton(
            icon: Icons.arrow_back_rounded,
            semanticLabel: 'Назад',
            onTap: () => context.pop(),
          ),
        ),
        actions: [
          if (canEdit)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _RoundHeaderButton(
                icon: Icons.edit_outlined,
                semanticLabel: 'Редактировать статью',
                onTap: () => unawaited(
                  context.pushNamed(
                    AppRouteNames.articleEditor,
                    queryParameters: {'articleId': articleId},
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 60),
        ],
      ),
      body: articleAsync.when(
        loading: () => const _ArticleLoadingSkeleton(),
        error: (_, _) => AppAsyncErrorView(
          message: 'Не удалось загрузить статью',
          onRetry: () => ref.invalidate(articleDetailsProvider(articleId)),
        ),
        data: (article) => RefreshIndicator(
          // Лайки, просмотры и комментарии живут своей жизнью, пока статья
          // открыта, — потянуть вниз должно обновлять их все.
          onRefresh: () async {
            ref.invalidate(articleDetailsProvider(articleId));
            ref.invalidate(articleCommentsProvider(articleId));
            ref.invalidate(articleRelatedProvider(articleId));
            await ref.read(articleDetailsProvider(articleId).future);
          },
          child: _ArticleBody(article: article),
        ),
      ),
    );
  }
}

class _ArticleLoadingSkeleton extends StatelessWidget {
  const _ArticleLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSkeleton(width: double.infinity, height: 200, borderRadius: 16),
            SizedBox(height: 16),
            AppSkeleton(width: 220, height: 24, borderRadius: 8),
            SizedBox(height: 12),
            AppSkeleton(width: double.infinity, height: 80, borderRadius: 8),
          ],
        ),
      ),
    );
  }
}

class _ArticleBody extends ConsumerWidget {
  const _ArticleBody({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final selfUserId = ref.watch(sessionProvider).userId;
    final isOwner = selfUserId != null && selfUserId == article.authorUserId;

    // Тап по любому месту вне поля и протяжка списка убирают клавиатуру:
    // в комментариях её нельзя было закрыть — на экране нет кнопки «Готово»,
    // а системная «назад» уводила со статьи (жалоба 2026-09-04).
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.shellBottomContent,
        ),
        children: [
          // Порядок по макету дизайнера: сначала кто и когда написал, потом
          // реакции, и только затем — о чём статья. Обложка отдельной
          // картинкой сверху больше не выводится: на макете первое
          // изображение живёт внутри текста, как обычный блок.
          _AuthorRow(
            name: article.authorDisplayName,
            avatarUrl: article.authorAvatarUrl,
            date: article.publishedAt ?? article.createdAt,
            readingTimeMinutes: article.readingTimeMinutes,
            rankTitle: article.authorRankTitle,
            config: config,
            onTap: () => _openAuthor(context, ref, article.authorUserId),
          ),
          const SizedBox(height: 12),
          _ReactionsPanel(article: article),
          const SizedBox(height: 18),
          Text(
            article.title,
            style: AppTypography.routeTitle.copyWith(
              fontSize: 22,
              color: AppColors.primaryInk,
            ),
          ),
          if (article.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            TagChipPicker.display(tags: article.tags),
          ],
          if (isOwner) ...[
            const SizedBox(height: 12),
            _OwnerArticleStatusBanner(
              status: article.status,
              articleId: article.id,
              note: article.moderatorNote,
            ),
          ],
          const SizedBox(height: 20),
          for (final block in article.sortedBlocks) ...[
            ArticleBlockView(block: block, config: config),
            const SizedBox(height: 16),
          ],
          if (article.relatedRouteId case final routeId?) ...[
            const SizedBox(height: 4),
            _RelatedRouteCard(routeId: routeId),
            const SizedBox(height: 24),
          ],
          _RelatedArticlesSection(articleId: article.id),
          const Divider(height: 1, color: Color(0xFFEDEDEE)),
          const SizedBox(height: 20),
          ArticleCommentsSection(articleId: article.id),
        ],
      ),
    );
  }

  void _openAuthor(BuildContext context, WidgetRef ref, String authorUserId) {
    final session = ref.read(sessionProvider);
    if (session.userId == authorUserId) {
      context.goNamed(AppRouteNames.profile);
    } else {
      // Standalone-вариант профиля: он на корневом навигаторе, поэтому
      // статья остаётся под ним и возврат ведёт в неё. Push в маршрут ветки
      // таба отсюда роняет Navigator на дублирующихся ключах страниц
      // ('!keyReservation.contains(key)') и оставляет пустой экран
      // (2026-09-03). См. _RelatedRouteCard.
      unawaited(
        context.pushNamed(
          AppRouteNames.userProfileStandalone,
          pathParameters: {'userId': authorUserId},
        ),
      );
    }
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.name,
    required this.avatarUrl,
    required this.date,
    required this.readingTimeMinutes,
    required this.config,
    required this.onTap,
    this.rankTitle,
  });

  final String name;
  final String? avatarUrl;
  final DateTime date;
  final int readingTimeMinutes;

  /// Звание автора под именем — как на макете дизайнера.
  final String? rankTitle;
  final AppConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: AppImages.imageProvider(
              resolvedUrl: AppImages.resolveMediaUrl(config, avatarUrl),
              assetFallback: AppImages.travelerPortrait,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryInk,
                  ),
                ),
                if (rankTitle != null && rankTitle!.isNotEmpty)
                  Text(
                    rankTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 11,
                      color: AppColors.secondaryInk,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Дата и время чтения — правым столбиком, как на макете: слева
          // «кто», справа «когда и насколько долго».
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(date),
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 12,
                  color: AppColors.primaryInk,
                ),
              ),
              Text(
                '$readingTimeMinutes ${_minutesWord(readingTimeMinutes)} чтения',
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 12,
                  color: AppColors.secondaryInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    const months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'мая',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return '$day ${months[local.month - 1]} ${local.year}';
  }

  static String _minutesWord(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) {
      return 'минута';
    }
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'минуты';
    }
    return 'минут';
  }
}

/// Like (tap = optimistic toggle) + view count (display-only). The like
/// state is a thin overlay on top of the fetched [Article] rather than an
/// `AsyncNotifier` + invalidate-refetch — a like should flip the instant
/// it's tapped, not wait on a round trip.
class _ReactionsPanel extends ConsumerWidget {
  const _ReactionsPanel({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlay = ref.watch(articleLikeOverlayProvider(article.id));
    final likeCount = overlay?.likeCount ?? article.likeCount;
    final likedByMe = overlay?.likedByMe ?? article.likedByMe;
    // Лайкать можно только опубликованную статью: на всё остальное бэкенд
    // отвечает 404 (`set_article_like`). Автор открывает свою статью на
    // модерации и видит ту же панель — тап приводил к ошибке вместо ответа
    // на вопрос «а что вообще происходит с моей статьёй» (баг 2026-09-03).
    final canLike = article.status == ArticleStatus.published;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        border: Border.all(color: const Color(0xFFEDEDEE)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: canLike
                ? () => unawaited(_toggleLike(context, ref, likedByMe))
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    likedByMe
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                    color: !canLike
                        ? AppColors.secondaryInk
                        : likedByMe
                        ? AppColors.accentBlue
                        : AppColors.primaryInk,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$likeCount',
                    style: TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: canLike
                          ? AppColors.primaryInk
                          : AppColors.secondaryInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Вертикальная черта между лайком и просмотрами — по макету
          // дизайнера; голый отступ читался как одна слитная группа цифр.
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0xFFE8E8EA),
          ),
          const Icon(
            Icons.visibility_outlined,
            size: 18,
            color: AppColors.secondaryInk,
          ),
          const SizedBox(width: 6),
          Text(
            '${article.viewCount}',
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryInk,
            ),
          ),
          const Spacer(),
          _SaveButton(article: article),
        ],
      ),
    );
  }

  Future<void> _toggleLike(
    BuildContext context,
    WidgetRef ref,
    bool currentlyLiked,
  ) async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      unawaited(context.pushNamed(AppRouteNames.authIdentity));
      return;
    }
    final overlayNotifier = ref.read(
      articleLikeOverlayProvider(article.id).notifier,
    );
    final previous = overlayNotifier.state;
    final optimisticCount = currentlyLiked
        ? (overlayNotifier.state?.likeCount ?? article.likeCount) - 1
        : (overlayNotifier.state?.likeCount ?? article.likeCount) + 1;
    overlayNotifier.state = ArticleLikeStatus(
      likeCount: optimisticCount,
      likedByMe: !currentlyLiked,
    );
    try {
      final result = await ref
          .read(articlesRepositoryProvider)
          .setLike(article.id, liked: !currentlyLiked);
      overlayNotifier.state = result;
    } on AppFailure catch (error) {
      overlayNotifier.state = previous;
      if (context.mounted) {
        showAppNotice(context, error.message);
      }
    } on Object {
      overlayNotifier.state = previous;
      if (context.mounted) {
        showAppNotice(context, 'Не удалось поставить лайк');
      }
    }
  }
}

/// Bookmark toggle — same optimistic overlay idea as the like, but private
/// and without a counter, so it only tracks one boolean.
class _SaveButton extends ConsumerWidget {
  const _SaveButton({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlay = ref.watch(articleSavedOverlayProvider(article.id));
    final saved = overlay ?? article.savedByMe;
    return Semantics(
      button: true,
      selected: saved,
      label: saved ? 'Убрать из сохранённых' : 'Сохранить статью',
      child: InkWell(
        onTap: () => unawaited(_toggle(context, ref, saved)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            size: 21,
            color: saved ? AppColors.accentBlue : AppColors.primaryInk,
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool currentlySaved,
  ) async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      unawaited(context.pushNamed(AppRouteNames.authIdentity));
      return;
    }
    final overlayNotifier = ref.read(
      articleSavedOverlayProvider(article.id).notifier,
    );
    final previous = overlayNotifier.state;
    overlayNotifier.state = !currentlySaved;
    try {
      final result = await ref
          .read(articlesRepositoryProvider)
          .setSaved(article.id, saved: !currentlySaved);
      overlayNotifier.state = result;
      ref.invalidate(savedArticlesProvider);
      if (context.mounted) {
        showAppNotice(
          context,
          result ? 'Статья сохранена' : 'Статья убрана из сохранённых',
        );
      }
    } on AppFailure catch (error) {
      overlayNotifier.state = previous;
      if (context.mounted) {
        showAppNotice(context, error.message);
      }
    } on Object {
      overlayNotifier.state = previous;
      if (context.mounted) {
        showAppNotice(context, 'Не удалось сохранить статью');
      }
    }
  }
}

/// "Читайте также" — published articles sharing at least one tag.
class _RelatedArticlesSection extends ConsumerWidget {
  const _RelatedArticlesSection({required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(articleRelatedProvider(articleId));
    final related = page.valueOrNull?.items;
    if (page.isLoading && page.valueOrNull == null) {
      // Заголовок не рисуем: пока неизвестно, есть ли вообще похожие статьи,
      // «Читайте также» над пустотой обещает то, чего может не оказаться.
      return const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: SizedBox(
          height: 320,
          child: ArticleCardSkeleton(width: 290, height: 320),
        ),
      );
    }
    if (related == null || related.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Читайте также', style: AppTypography.sectionTitle),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: related.length,
              separatorBuilder: (context, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  ArticleCard(article: related[index], width: 290, height: 320),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerArticleStatusBanner extends StatelessWidget {
  const _OwnerArticleStatusBanner({
    required this.status,
    required this.articleId,
    this.note,
  });

  final ArticleStatus status;
  final String articleId;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final (icon, label, description) = switch (status) {
      ArticleStatus.pendingReview => (
        Icons.schedule_rounded,
        'На модерации',
        'Статью проверяет команда модерации. Пока она видна только вам.',
      ),
      ArticleStatus.rejected => (
        Icons.info_outline_rounded,
        'Отклонена',
        note ?? 'Перед публикацией статье нужны исправления.',
      ),
      ArticleStatus.draft => (
        Icons.edit_note_rounded,
        'Черновик',
        'Виден только вам, пока вы не отправите его на модерацию.',
      ),
      ArticleStatus.published => (
        Icons.check_circle_outline_rounded,
        'Опубликована',
        'Правки отправят статью на повторную проверку — пока её не одобрят, '
            'читатели её не увидят.',
      ),
      ArticleStatus.deleted => (Icons.delete_outline_rounded, 'Удалена', ''),
    };
    return Container(
      key: const ValueKey('article-owner-status'),
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accentBlue, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: AppTypography.chip.copyWith(
                        color: AppColors.primaryInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Править можно всё, кроме удалённой: бэкенд принимает
                    // черновик, отклонённую, ждущую проверки и уже
                    // опубликованную (последняя вернётся на модерацию).
                    if (status != ArticleStatus.deleted)
                      TextButton(
                        onPressed: () => unawaited(
                          context.pushNamed(
                            AppRouteNames.articleEditor,
                            queryParameters: {'articleId': articleId},
                          ),
                        ),
                        child: const Text('Редактировать'),
                      ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: AppTypography.routeMetadata.copyWith(
                      color: AppColors.secondaryInk,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedRouteCard extends StatelessWidget {
  const _RelatedRouteCard({required this.routeId});

  final String routeId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.controlSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // Standalone-вариант деталей маршрута: он объявлен на корневом
        // навигаторе, поэтому статья остаётся под ним и возврат ведёт обратно
        // в неё. Push в `/routes/:id` (маршрут ветки таба) отсюда роняет
        // Navigator и даёт пустой экран.
        onTap: () => unawaited(
          context.pushNamed(
            AppRouteNames.routeDetailsStandalone,
            pathParameters: {'id': routeId},
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.route_outlined, color: AppColors.primaryInk),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Статья о маршруте',
                  style: TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryInk,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.secondaryInk),
            ],
          ),
        ),
      ),
    );
  }
}

/// Серый вордмарк в шапке — как на макете: экран статьи не подписывается
/// её заголовком, заголовок живёт в теле.
class _HeaderWordmark extends StatelessWidget {
  const _HeaderWordmark();

  @override
  Widget build(BuildContext context) {
    return Text(
      'КРЫМТРИП',
      style: AppTypography.chip.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 3.3,
        color: const Color(0xFFB8B9BD),
      ),
    );
  }
}

/// Круглая тёмная кнопка в шапке.
class _RoundHeaderButton extends StatelessWidget {
  const _RoundHeaderButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: AppColors.primaryInk,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
