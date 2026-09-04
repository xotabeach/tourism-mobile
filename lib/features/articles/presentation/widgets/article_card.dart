import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_expert_style.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/article_images.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Article card for a feed/section — the "Мои статьи" profile section, the
/// route-details "Статьи об этом маршруте" block, "Читайте также" and the
/// saved-articles tab all share this.
///
/// Photo on top with the tag and date floating over it, then a white body
/// carrying the headline, the opening line and an author/metrics footer. An
/// article, unlike a route, is sold by its words: a full-bleed photo card
/// leaves room for a title and nothing else, and the excerpt is what makes
/// someone open it.
/// Headline (2 lines) + excerpt (2 lines) + footer, plus the body padding.
const _bodyHeight = 152.0;

class ArticleCard extends ConsumerWidget {
  const ArticleCard({
    required this.article,
    this.width = double.infinity,
    this.height = 330,
    this.showStatus = false,
    super.key,
  });

  final ArticleSummary article;
  final double width;
  final double height;

  /// Own-profile "Мои статьи" shows draft/pending/rejected badges too.
  final bool showStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final cover = articleImageProvider(
      config: config,
      url: article.coverImageUrl,
      fallbackSeed: article.id,
    );
    final showDraftBadge =
        showStatus && article.status != ArticleStatus.published;

    return AppPressableScale(
      borderRadius: AppRadii.card,
      onTap: () => unawaited(
        context.pushNamed(
          AppRouteNames.articleDetails,
          pathParameters: {'id': article.id},
        ),
      ),
      child: AppExpertFrame(
        isExpert: article.authorIsExpert,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: const Color(0xFFEDEDEE)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    // The body is the fixed part — headline, two lines of
                    // excerpt and the footer all have to fit whatever the card's
                    // height is — so the photo takes what is left over, not a
                    // fraction that would starve the text on a shorter card.
                    height: (height - _bodyHeight).clamp(110.0, height),
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(image: cover, fit: BoxFit.cover),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (article.tags.isNotEmpty)
                                Flexible(
                                  child: _TagPill(tag: article.tags.first),
                                ),
                              const Spacer(),
                              if (showDraftBadge)
                                _StatusPill(status: article.status)
                              else
                                _DatePill(
                                  date:
                                      article.publishedAt ?? article.createdAt,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.routeTitle.copyWith(
                              fontSize: 16,
                              height: 1.25,
                              color: AppColors.primaryInk,
                            ),
                          ),
                          if (article.excerpt case final excerpt?
                              when excerpt.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              excerpt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.routeMetadata.copyWith(
                                fontSize: 13,
                                height: 1.3,
                                color: AppColors.secondaryInk,
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Линия отделяет лид от строки автора — как на макете.
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFEDEDEE),
                          ),
                          const SizedBox(height: 10),
                          _CardFooter(article: article),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return AppGlassPill(
      blur: 8,
      fillColor: Colors.black.withValues(alpha: 0.42),
      borderColor: Colors.white.withValues(alpha: 0.16),
      contentColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        tag,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.routeMetadata.copyWith(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final local = date.toLocal();
    final text =
        '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.capsule),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          style: AppTypography.routeMetadata.copyWith(
            fontSize: 13,
            color: AppColors.primaryInk,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CardFooter extends StatelessWidget {
  const _CardFooter({required this.article});

  final ArticleSummary article;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final config = ref.watch(appConfigProvider);
        // Тот же оверлей, что и на экране чтения: лайк, поставленный внутри
        // статьи, должен быть виден и на карточке. Раньше карточка знала
        // только про число из своего списка, и после лайка счётчики
        // расходились до следующей перезагрузки списка (баг 2026-09-03).
        final likeOverlay = ref.watch(articleLikeOverlayProvider(article.id));
        final likeCount = likeOverlay?.likeCount ?? article.likeCount;
        final likedByMe = likeOverlay?.likedByMe ?? article.likedByMe;
        final avatar = AppImages.imageProvider(
          resolvedUrl: AppImages.resolveMediaUrl(
            config,
            article.authorAvatarUrl,
          ),
          assetFallback: AppImages.travelerPortrait,
        );
        return Row(
          children: [
            AppExpertFrame(
              isExpert: article.authorIsExpert,
              borderRadius: BorderRadius.circular(17),
              child: CircleAvatar(radius: 17, backgroundImage: avatar),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    article.authorDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.chip.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryInk,
                    ),
                  ),
                  if (article.authorRankTitle case final rank?
                      when rank.isNotEmpty)
                    Text(
                      rank,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.routeMetadata.copyWith(
                        fontSize: 10,
                        height: 1.2,
                        color: AppColors.secondaryInk,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _MetricChip(
              icon: Icons.alarm,
              label: '${article.readingTimeMinutes} мин',
            ),
            // Вертикальная черта вместо рамок вокруг каждой метрики.
            Container(
              width: 1,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: const Color(0xFFE8E8EA),
            ),
            _MetricChip(
              icon: likedByMe
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: '$likeCount',
              // В макете сердце синее, в тон акценту приложения, а не красное.
              iconColor: AppColors.accentBlue,
            ),
          ],
        );
      },
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label, this.iconColor});

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    // Без рамки: на макете метрики стоят прямо в строке, а время и лайки
    // разделены вертикальной чертой (её рисует вызывающий).
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor ?? AppColors.secondaryInk),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.routeMetadata.copyWith(
            fontSize: 13,
            color: AppColors.primaryInk,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ArticleStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ArticleStatus.draft => 'Черновик',
      ArticleStatus.pendingReview => 'На модерации',
      ArticleStatus.rejected => 'Отклонена',
      ArticleStatus.published || ArticleStatus.deleted => '',
    };
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.capsule),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: AppTypography.routeMetadata.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryInk,
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder with the card's own silhouette — photo block, two
/// headline lines, a lead line and the author/metrics footer.
///
/// Sections that show one of these while loading must not fall through to
/// their empty state first: on a own profile that meant flashing "Вы ещё не
/// написали ни одной статьи" at an author who has written several.
class ArticleCardSkeleton extends StatelessWidget {
  const ArticleCardSkeleton({
    this.width = double.infinity,
    this.height = 330,
    super.key,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: const Color(0xFFEDEDEE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Same split as ArticleCard: the body is fixed, the photo takes
              // what is left, so the skeleton keeps the card's proportions.
              AppSkeleton(
                width: double.infinity,
                height: (height - _bodyHeight).clamp(110.0, height),
                borderRadius: AppRadii.card,
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(
                        width: double.infinity,
                        height: 16,
                        borderRadius: 8,
                      ),
                      SizedBox(height: 7),
                      AppSkeleton(width: 180, height: 16, borderRadius: 8),
                      SizedBox(height: 9),
                      AppSkeleton(
                        width: double.infinity,
                        height: 12,
                        borderRadius: 6,
                      ),
                      Spacer(),
                      Row(
                        children: [
                          AppSkeleton(width: 34, height: 34, borderRadius: 17),
                          SizedBox(width: 9),
                          // Гибкая, как колонка автора в самой карточке: на
                          // узком варианте (290px в ряду «Читайте также»)
                          // фиксированные полоски не помещались рядом с
                          // пилюлями метрик.
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppSkeleton(
                                  width: 96,
                                  height: 12,
                                  borderRadius: 6,
                                ),
                                SizedBox(height: 5),
                                AppSkeleton(
                                  width: 132,
                                  height: 10,
                                  borderRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 6),
                          AppSkeleton(
                            width: 66,
                            height: 28,
                            borderRadius: AppRadii.capsule,
                          ),
                          SizedBox(width: 8),
                          AppSkeleton(
                            width: 52,
                            height: 28,
                            borderRadius: AppRadii.capsule,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
