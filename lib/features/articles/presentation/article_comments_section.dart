import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/domain/articles_repository.dart';
import 'package:tourism_mobile/features/moderation/domain/content_report.dart';
import 'package:tourism_mobile/features/moderation/presentation/report_sheet.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/reviews/presentation/reply_quote.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Comments thread for one article (G.8b). Deliberately hand-rolled rather
/// than reusing `EntityReviewsSection` — that widget is tightly coupled to
/// star ratings and review vocabulary, which articles have neither of.
class ArticleCommentsSection extends ConsumerStatefulWidget {
  const ArticleCommentsSection({required this.articleId, super.key});

  final String articleId;

  @override
  ConsumerState<ArticleCommentsSection> createState() =>
      _ArticleCommentsSectionState();
}

class _ArticleCommentsSectionState
    extends ConsumerState<ArticleCommentsSection> {
  final _composerFocus = FocusNode();
  ArticleComment? _replyTarget;

  @override
  void dispose() {
    _composerFocus.dispose();
    super.dispose();
  }

  void _invalidate() {
    ref.invalidate(articleCommentsProvider(widget.articleId));
  }

  void _startReply(ArticleComment comment) {
    setState(() => _replyTarget = comment);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _composerFocus.requestFocus();
      }
    });
  }

  void _cancelReply() {
    if (!mounted || _replyTarget == null) {
      return;
    }
    setState(() => _replyTarget = null);
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(articleCommentsProvider(widget.articleId));
    final selfUserId = ref.watch(sessionProvider).userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Комментарии', style: AppTypography.sectionTitle),
        const SizedBox(height: 14),
        _ArticleCommentComposer(
          articleId: widget.articleId,
          focusNode: _composerFocus,
          replyTo: _replyTarget,
          onCancelReply: _cancelReply,
          onSubmitted: () {
            _cancelReply();
            _invalidate();
          },
        ),
        const SizedBox(height: 14),
        commentsAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          skipError: true,
          loading: () => const _CommentsLoadingSkeleton(),
          error: (_, _) => AppAsyncErrorView(
            message: 'Не удалось загрузить комментарии',
            onRetry: _invalidate,
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Комментариев пока нет',
                  style: TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 13,
                    color: AppColors.secondaryInk,
                  ),
                ),
              );
            }
            // One flat list, as in route reviews: a reply is a card of its
            // own that quotes what it answers.
            final byId = {
              for (final comment in page.items) comment.id: comment,
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final comment in page.items) ...[
                  _ArticleCommentTile(
                    comment: comment,
                    repliesTo: byId[comment.replyToCommentId],
                    isOwn: comment.authorUserId == selfUserId,
                    canDelete: _canDelete(comment, selfUserId),
                    onReply: () => _startReply(comment),
                    onDeleted: _invalidate,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  static bool _canDelete(ArticleComment comment, String? selfUserId) {
    if (selfUserId == null ||
        selfUserId.isEmpty ||
        comment.authorUserId != selfUserId) {
      return false;
    }
    final age = DateTime.now().toUtc().difference(comment.createdAt.toUtc());
    return age <= ArticleLimits.commentDeleteWindow;
  }
}

class _CommentsLoadingSkeleton extends StatelessWidget {
  const _CommentsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSkeleton(width: double.infinity, height: 64, borderRadius: 14),
          SizedBox(height: 10),
          AppSkeleton(width: double.infinity, height: 64, borderRadius: 14),
        ],
      ),
    );
  }
}

class _ArticleCommentTile extends ConsumerStatefulWidget {
  const _ArticleCommentTile({
    required this.comment,
    required this.repliesTo,
    required this.isOwn,
    required this.canDelete,
    required this.onReply,
    required this.onDeleted,
  });

  final ArticleComment comment;

  /// The comment this one answers, when it is on the loaded page.
  final ArticleComment? repliesTo;

  /// На свой комментарий жаловаться незачем — щит показывается только на
  /// чужих (сервер такую жалобу и не примет).
  final bool isOwn;
  final bool canDelete;
  final VoidCallback onReply;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_ArticleCommentTile> createState() =>
      _ArticleCommentTileState();
}

class _ArticleCommentTileState extends ConsumerState<_ArticleCommentTile> {
  /// Длинный комментарий на макете свёрнут до четырёх строк со ссылкой
  /// «Читать полностью» — иначе один многословный отзыв занимает экран.
  static const _collapsedLines = 4;
  static const _bodyStyle = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.secondaryInk,
  );

  bool _expanded = false;

  ArticleComment get comment => widget.comment;
  bool get isOwn => widget.isOwn;
  bool get canDelete => widget.canDelete;
  VoidCallback get onReply => widget.onReply;
  VoidCallback get onDeleted => widget.onDeleted;

  bool get _pending => comment.status == ArticleCommentStatus.pendingReview;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    return Opacity(
      opacity: _pending ? 0.72 : 1,
      child: Container(
        key: ValueKey('article-comment-${comment.id}'),
        // The route review card's look (see _ReviewCard in reviews).
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDEDEE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_pending)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'На проверке',
                  key: ValueKey('article-comment-pending-badge'),
                  style: TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryInk,
                  ),
                ),
              ),
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundImage: AppImages.imageProvider(
                    resolvedUrl: AppImages.resolveMediaUrl(
                      config,
                      comment.authorAvatarUrl,
                    ),
                    assetFallback: AppImages.travelerPortrait,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        comment.authorDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: AppColors.primaryInk,
                        ),
                      ),
                      // Ранг под именем — как на макете: он объясняет, кому
                      // принадлежит совет, а не просто занимает строку.
                      if (comment.authorRankTitle case final rank?)
                        Text(
                          rank,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.rubik,
                            fontSize: 11,
                            height: 1.3,
                            color: AppColors.secondaryInk,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isOwn)
                  Semantics(
                    button: true,
                    label: 'Пожаловаться на комментарий',
                    child: InkResponse(
                      key: ValueKey('article-comment-report-${comment.id}'),
                      radius: 22,
                      onTap: () => unawaited(
                        showReportSheet(
                          context,
                          ref,
                          targetType: ReportTargetType.articleComment,
                          targetId: comment.id,
                          title: 'Комментарий · ${comment.authorDisplayName}',
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.report_gmailerrorred_rounded,
                          size: 21,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (widget.repliesTo case final parent?) ...[
              ReplyQuote(
                key: ValueKey('article-comment-reply-${comment.id}'),
                title: parent.authorDisplayName,
                body: parent.body,
              ),
              const SizedBox(height: 10),
            ],
            // Замер и текст, и строка действий — в одном LayoutBuilder:
            // builder выполняется на этапе layout, и признак переполнения,
            // выставленный «наружу», отставал бы на один кадр.
            LayoutBuilder(
              builder: (context, constraints) {
                final painter = TextPainter(
                  text: TextSpan(text: comment.body, style: _bodyStyle),
                  maxLines: _collapsedLines,
                  textDirection: Directionality.of(context),
                )..layout(maxWidth: constraints.maxWidth);
                final overflows = painter.didExceedMaxLines;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.body,
                      maxLines: _expanded ? null : _collapsedLines,
                      overflow: _expanded
                          ? TextOverflow.clip
                          : TextOverflow.ellipsis,
                      style: _bodyStyle,
                    ),
                    if (overflows) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        key: const ValueKey('article-comment-expand'),
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Text(
                          _expanded ? 'Свернуть' : 'Читать полностью',
                          style: AppTypography.button.copyWith(
                            fontSize: 13,
                            color: AppColors.primaryInk,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Spacer(),
                        GestureDetector(
                          onTap: onReply,
                          child: Text(
                            'Ответить',
                            style: AppTypography.button.copyWith(
                              fontSize: 13,
                              color: AppColors.primaryInk,
                            ),
                          ),
                        ),
                        if (canDelete) ...[
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: () =>
                                unawaited(_confirmDelete(context, ref)),
                            child: Text(
                              'Удалить',
                              style: AppTypography.button.copyWith(
                                fontSize: 13,
                                color: AppColors.secondaryInk,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить комментарий?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(articlesRepositoryProvider)
          .deleteComment(comment.articleId, comment.id);
      onDeleted();
    } on AppFailure catch (failure) {
      if (context.mounted) {
        showAppNotice(context, failure.message);
      }
    } on Object {
      if (context.mounted) {
        showAppNotice(context, 'Не удалось удалить комментарий');
      }
    }
  }
}

class _ArticleCommentComposer extends ConsumerStatefulWidget {
  const _ArticleCommentComposer({
    required this.articleId,
    required this.focusNode,
    required this.replyTo,
    required this.onCancelReply,
    required this.onSubmitted,
  });

  final String articleId;
  final FocusNode focusNode;
  final ArticleComment? replyTo;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_ArticleCommentComposer> createState() =>
      _ArticleCommentComposerState();
}

class _ArticleCommentComposerState
    extends ConsumerState<_ArticleCommentComposer> {
  final _controller = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      unawaited(context.pushNamed(AppRouteNames.authIdentity));
      return;
    }
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(articlesRepositoryProvider)
          .createComment(
            widget.articleId,
            body,
            replyToCommentId: widget.replyTo?.id,
          );
      _controller.clear();
      widget.onSubmitted();
      if (!mounted) {
        return;
      }
      showAppNotice(context, 'Комментарий отправлен на модерацию');
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message);
      }
    } on Object {
      if (mounted) {
        showAppNotice(context, 'Не удалось отправить комментарий');
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  static OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    final used = _controller.text.characters.length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E4E6)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.replyTo case final target?) ...[
            ReplyQuote(
              key: const ValueKey('article-comment-reply-composer-context'),
              title: 'Ответ для ${target.authorDisplayName}',
              body: target.body,
              onCancel: widget.onCancelReply,
            ),
            const SizedBox(height: 8),
          ],
          Stack(
            children: [
              TextField(
                controller: _controller,
                focusNode: widget.focusNode,
                minLines: 2,
                maxLines: 4,
                maxLength: ArticleLimits.maxCommentLength,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 14,
                  color: AppColors.primaryInk,
                ),
                decoration: InputDecoration(
                  hintText: 'Напишите комментарий',
                  filled: true,
                  fillColor: const Color(0xFFF0F0F0),
                  // Every state needs its own border: otherwise the enabled
                  // and focused ones come from the theme's round (22 dp)
                  // field shape, which is what the design flagged.
                  border: _fieldBorder(const Color(0xFFD9D9DB)),
                  enabledBorder: _fieldBorder(const Color(0xFFD9D9DB)),
                  focusedBorder: _fieldBorder(AppColors.primaryInk),
                  disabledBorder: _fieldBorder(const Color(0xFFE4E4E6)),
                  counterText: '',
                  contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 6,
                child: Text(
                  '$used/${ArticleLimits.maxCommentLength}',
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 11,
                    color: AppColors.secondaryInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: _sending ? null : _submit,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryInk,
                side: const BorderSide(color: Color(0xFFD9D9DB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(21),
                ),
              ),
              child: Text(_sending ? 'Отправка…' : 'Отправить'),
            ),
          ),
        ],
      ),
    );
  }
}
