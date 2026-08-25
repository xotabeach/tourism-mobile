import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/places/application/place_reviews_providers.dart';
import 'package:tourism_mobile/features/places/data/place_reviews_repository.dart';
import 'package:tourism_mobile/features/routes/application/route_reviews_providers.dart';
import 'package:tourism_mobile/features/routes/data/route_reviews_repository.dart';
import 'package:tourism_mobile/routing/app_router.dart';

enum ReviewEntityKind { place, route }

void invalidateEntityReviews(
  WidgetRef ref,
  ReviewEntityKind kind,
  String entityId,
) {
  switch (kind) {
    case ReviewEntityKind.place:
      ref
        ..invalidate(placeReviewsProvider(entityId))
        ..invalidate(myPlaceReviewsProvider);
    case ReviewEntityKind.route:
      ref
        ..invalidate(routeReviewsProvider(entityId))
        ..invalidate(myRouteReviewsProvider);
  }
}

Future<void> submitEntityReview(
  WidgetRef ref, {
  required ReviewEntityKind kind,
  required String entityId,
  required String body,
  required int rating,
  required List<String> imagePaths,
  String? replyToReviewId,
}) {
  return switch (kind) {
    ReviewEntityKind.place =>
      ref
          .read(placeReviewsRepositoryProvider)
          .submit(
            placeId: entityId,
            body: body,
            rating: rating,
            imagePaths: imagePaths,
            replyToReviewId: replyToReviewId,
          ),
    ReviewEntityKind.route =>
      ref
          .read(routeReviewsRepositoryProvider)
          .submit(
            routeId: entityId,
            body: body,
            rating: rating,
            imagePaths: imagePaths,
            replyToReviewId: replyToReviewId,
          ),
  };
}

Future<void> deleteEntityReview(
  WidgetRef ref, {
  required ReviewEntityKind kind,
  required String entityId,
  required String reviewId,
}) {
  return switch (kind) {
    ReviewEntityKind.place =>
      ref
          .read(placeReviewsRepositoryProvider)
          .delete(placeId: entityId, reviewId: reviewId),
    ReviewEntityKind.route =>
      ref
          .read(routeReviewsRepositoryProvider)
          .delete(routeId: entityId, reviewId: reviewId),
  };
}

class EntityReviewsSection extends ConsumerStatefulWidget {
  const EntityReviewsSection({
    required this.entityId,
    required this.kind,
    this.allowComposer = true,
    super.key,
  });

  final String entityId;
  final ReviewEntityKind kind;
  final bool allowComposer;

  @override
  ConsumerState<EntityReviewsSection> createState() =>
      _EntityReviewsSectionState();
}

enum _ReviewListFilter { all, newest, oldest, withPhoto }

class _EntityReviewsSectionState extends ConsumerState<EntityReviewsSection> {
  final _composerFocus = FocusNode();
  var _filter = _ReviewListFilter.all;
  RouteReview? _replyTarget;

  @override
  void dispose() {
    _composerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.allowComposer) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Text(
          widget.kind == ReviewEntityKind.place
              ? 'Отзывы можно оставлять только к опубликованным местам'
              : 'Отзывы можно оставлять только к опубликованным маршрутам',
          key: const ValueKey('reviews-unpublished-hint'),
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 14,
            height: 1.35,
            color: AppColors.secondaryInk,
          ),
        ),
      );
    }

    final reviewsAsync = switch (widget.kind) {
      ReviewEntityKind.place => ref.watch(
        placeReviewsProvider(widget.entityId),
      ),
      ReviewEntityKind.route => ref.watch(
        routeReviewsProvider(widget.entityId),
      ),
    };
    final myReviewsAsync = switch (widget.kind) {
      ReviewEntityKind.place => ref.watch(myPlaceReviewsProvider),
      ReviewEntityKind.route => ref.watch(myRouteReviewsProvider),
    };
    final selfUserId = ref.watch(sessionProvider).userId;
    final pendingCandidates = myReviewsAsync.maybeWhen(
      data: (items) => items
          .where(
            (r) => r.routeId == widget.entityId && r.status == 'pending_review',
          )
          .toList(),
      orElse: () => const <RouteReview>[],
    );
    final allMineForRoute = myReviewsAsync.maybeWhen(
      data: (items) => [
        for (final review in items)
          if (review.routeId == widget.entityId) review,
      ],
      orElse: () => const <RouteReview>[],
    );
    RouteReview? ownRootReview;
    for (final review in allMineForRoute) {
      if (review.replyTo == null &&
          (review.status == 'published' || review.status == 'pending_review')) {
        ownRootReview = review;
        break;
      }
    }

    return reviewsAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => const _ReviewsLoadingSkeleton(),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Не удалось загрузить отзывы',
            style: TextStyle(color: AppColors.secondaryInk),
          ),
          TextButton(
            onPressed: () =>
                invalidateEntityReviews(ref, widget.kind, widget.entityId),
            child: const Text('Повторить'),
          ),
          const SizedBox(height: 12),
          if (ownRootReview == null || _replyTarget != null)
            _ReviewComposer(
              entityId: widget.entityId,
              kind: widget.kind,
              focusNode: _composerFocus,
              replyTo: _replyTarget,
              onCancelReply: _cancelReply,
              onSubmitted: _cancelReply,
            ),
        ],
      ),
      data: (page) {
        final pendingMine = pendingReviewsNotYetPublished(
          pending: pendingCandidates,
          published: page.items,
        );
        final pinned = ownRootReview;
        final visible = _applyFilter([
          for (final review in page.items)
            if (review.id != pinned?.id) review,
        ]);
        final pendingOthers = [
          for (final review in pendingMine)
            if (review.id != pinned?.id) review,
        ];
        final ratingLabel = page.averageRating == null
            ? '—'
            : page.averageRating!.toStringAsFixed(1).replaceAll('.', ',');
        final topLabel = page.ratingCount == 0
            ? 'Пока нет отзывов'
            : '${page.ratingCount} ${_reviewsWord(page.ratingCount)}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RatingRow(rating: ratingLabel, topLabel: topLabel),
            const SizedBox(height: 14),
            if (pinned == null || _replyTarget != null) ...[
              _ReviewComposer(
                entityId: widget.entityId,
                kind: widget.kind,
                focusNode: _composerFocus,
                replyTo: _replyTarget,
                onCancelReply: _cancelReply,
                onSubmitted: _cancelReply,
              ),
              const SizedBox(height: 14),
            ],
            if (pinned != null) ...[
              const Text(
                'Ваш отзыв',
                key: ValueKey('own-review-pinned-label'),
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryInk,
                ),
              ),
              const SizedBox(height: 8),
              _ReviewCard(
                kind: widget.kind,
                key: ValueKey('own-review-pinned-${pinned.id}'),
                review: pinned,
                pending: pinned.status == 'pending_review',
                canDelete: _canDeleteReview(pinned, selfUserId),
                onReply: () => _startReply(pinned),
              ),
              const SizedBox(height: 14),
            ],
            AppFilterChipBar(
              labels: const ['Все', 'Новые', 'Старые', 'С фото'],
              selected: switch (_filter) {
                _ReviewListFilter.all => 'Все',
                _ReviewListFilter.newest => 'Новые',
                _ReviewListFilter.oldest => 'Старые',
                _ReviewListFilter.withPhoto => 'С фото',
              },
              onSelected: (label) {
                setState(() {
                  _filter = switch (label) {
                    'Новые' => _ReviewListFilter.newest,
                    'Старые' => _ReviewListFilter.oldest,
                    'С фото' => _ReviewListFilter.withPhoto,
                    _ => _ReviewListFilter.all,
                  };
                });
              },
            ),
            const SizedBox(height: 14),
            for (final review in pendingOthers) ...[
              _ReviewCard(
                kind: widget.kind,
                review: review,
                pending: true,
                canDelete: _canDeleteReview(review, selfUserId),
                onReply: () => _startReply(review),
              ),
              const SizedBox(height: 12),
            ],
            for (final review in visible) ...[
              _ReviewCard(
                kind: widget.kind,
                review: review,
                pending: false,
                canDelete: _canDeleteReview(review, selfUserId),
                onReply: () => _startReply(review),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  void _startReply(RouteReview review) {
    setState(() => _replyTarget = review);
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

  List<RouteReview> _applyFilter(List<RouteReview> items) {
    switch (_filter) {
      case _ReviewListFilter.all:
        return items;
      case _ReviewListFilter.newest:
        return [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _ReviewListFilter.oldest:
        return [...items]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _ReviewListFilter.withPhoto:
        return [
          for (final review in items)
            if (review.media.isNotEmpty) review,
        ];
    }
  }

  static bool _canDeleteReview(RouteReview review, String? selfUserId) {
    if (!_ownsReview(review, selfUserId)) {
      return false;
    }
    final age = DateTime.now().toUtc().difference(review.createdAt.toUtc());
    return age <= const Duration(hours: 6);
  }

  static bool _ownsReview(RouteReview review, String? selfUserId) {
    return selfUserId != null &&
        selfUserId.isNotEmpty &&
        review.authorUserId == selfUserId;
  }

  static String _reviewsWord(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) {
      return 'отзыв';
    }
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'отзывы';
    }
    return 'отзывов';
  }
}

class _ReviewsLoadingSkeleton extends StatelessWidget {
  const _ReviewsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSkeleton(width: 72, height: 30, borderRadius: 12),
                AppSkeleton(width: 92, height: 18, borderRadius: 7),
              ],
            ),
            SizedBox(height: 14),
            AppSkeleton(width: double.infinity, height: 222, borderRadius: 16),
            SizedBox(height: 14),
            AppSkeleton(width: double.infinity, height: 36, borderRadius: 18),
            SizedBox(height: 14),
            AppSkeleton(width: double.infinity, height: 170, borderRadius: 16),
          ],
        ),
      ),
    );
  }
}

/// Pending cards that are not already present in the published list (by id).
@visibleForTesting
List<RouteReview> pendingReviewsNotYetPublished({
  required List<RouteReview> pending,
  required List<RouteReview> published,
}) {
  if (pending.isEmpty) {
    return const [];
  }
  final publishedIds = {for (final review in published) review.id};
  return [
    for (final review in pending)
      if (!publishedIds.contains(review.id)) review,
  ];
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating, required this.topLabel});

  final String rating;
  final String topLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryInk,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, size: 18, color: AppColors.rating),
              const SizedBox(width: 6),
              Text(
                rating,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          topLabel,
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: AppColors.primaryInk,
          ),
        ),
      ],
    );
  }
}

class _ReviewComposer extends ConsumerStatefulWidget {
  const _ReviewComposer({
    required this.entityId,
    required this.kind,
    required this.focusNode,
    required this.replyTo,
    required this.onCancelReply,
    required this.onSubmitted,
  });

  final String entityId;
  final ReviewEntityKind kind;
  final FocusNode focusNode;
  final RouteReview? replyTo;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends ConsumerState<_ReviewComposer>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _composerKey = GlobalKey();
  var _rating = 5;
  var _sending = false;
  var _lastViewInset = 0.0;
  final _images = <XFile>[];

  static const _maxChars = 500;
  static const _maxImages = 6;
  static const _maxImageBytes = 10 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.focusNode.addListener(_onComposerFocusChange);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.focusNode.removeListener(_onComposerFocusChange);
    _controller.dispose();
    super.dispose();
  }

  void _onComposerFocusChange() {
    if (!widget.focusNode.hasFocus) {
      return;
    }
    _ensureComposerVisible(animate: true);
    _ensureComposerVisibleSoon();
  }

  double _keyboardInset() {
    final view = View.of(context);
    return MediaQueryData.fromView(view).viewInsets.bottom;
  }

  @override
  void didChangeMetrics() {
    if (!mounted) {
      return;
    }
    final inset = _keyboardInset();
    final opened = inset > _lastViewInset + 1;
    _lastViewInset = inset;
    if (opened || (inset > 0 && widget.focusNode.hasFocus)) {
      _ensureComposerVisible(animate: false);
      if (opened) {
        _ensureComposerVisibleSoon();
      }
    }
  }

  void _ensureComposerVisibleSoon() {
    for (final delay in const [
      Duration(milliseconds: 50),
      Duration(milliseconds: 160),
      Duration(milliseconds: 320),
    ]) {
      Future<void>.delayed(delay, () {
        if (!mounted || !widget.focusNode.hasFocus) {
          return;
        }
        _ensureComposerVisible(animate: false);
      });
    }
  }

  void _ensureComposerVisible({required bool animate}) {
    final targetContext = _composerKey.currentContext;
    if (targetContext == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.focusNode.hasFocus) {
        return;
      }
      final ctx = _composerKey.currentContext;
      if (ctx == null) {
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.55,
          duration: animate ? const Duration(milliseconds: 220) : Duration.zero,
          curve: Curves.easeOut,
        ),
      );
    });
  }

  Future<void> _pickImages() async {
    final available = _maxImages - _images.length;
    if (available <= 0 || _sending) {
      return;
    }
    try {
      final picked = await ImagePicker().pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 86,
        limit: available,
        requestFullMetadata: false,
      );
      final accepted = <XFile>[];
      for (final image in picked) {
        if (await image.length() <= _maxImageBytes) {
          accepted.add(image);
        }
      }
      if (!mounted) {
        return;
      }
      setState(() => _images.addAll(accepted.take(available)));
      if (accepted.length != picked.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото больше 10 МБ не добавлены')),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось выбрать фотографии')),
        );
      }
    }
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
      await submitEntityReview(
        ref,
        kind: widget.kind,
        entityId: widget.entityId,
        body: body,
        rating: _rating,
        imagePaths: [for (final image in _images) image.path],
        replyToReviewId: widget.replyTo?.id,
      );
      _controller.clear();
      setState(() {
        _images.clear();
        _rating = 5;
      });
      widget.onSubmitted();
      invalidateEntityReviews(ref, widget.kind, widget.entityId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.replyTo == null
                ? 'Отзыв отправлен на модерацию'
                : 'Ответ отправлен на модерацию',
          ),
        ),
      );
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить отзыв')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final used = _controller.text.characters.length;
    return Container(
      key: _composerKey,
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E4E6)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.replyTo != null) ...[
            _ReplyComposerContext(
              review: widget.replyTo!,
              onCancel: widget.onCancelReply,
            ),
            const SizedBox(height: 10),
          ],
          Text(
            widget.replyTo == null ? 'Ваш отзыв:' : 'Ваш ответ:',
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryInk,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              for (var index = 1; index <= 5; index++) ...[
                InkResponse(
                  radius: 22,
                  onTap: () => setState(() => _rating = index),
                  child: Icon(
                    index <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.rating,
                    size: 32,
                  ),
                ),
                if (index != 5) const SizedBox(width: 2),
              ],
              const Spacer(),
              Material(
                color: const Color(0xFFF0F0F1),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Очистить',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _controller.clear();
                    setState(() {
                      _rating = 5;
                      _images.clear();
                    });
                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.primaryInk,
                    size: 23,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              TextField(
                controller: _controller,
                focusNode: widget.focusNode,
                minLines: 4,
                maxLines: 6,
                maxLength: _maxChars,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 14,
                  color: AppColors.primaryInk,
                  height: 1.35,
                ),
                decoration: InputDecoration(
                  hintText: widget.kind == ReviewEntityKind.place
                      ? 'Поделитесь впечатлениями о месте'
                      : 'Поделитесь впечатлениями о маршруте',
                  hintStyle: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 14,
                    color: AppColors.secondaryInk,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF0F0F0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD9D9DB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD9D9DB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryInk),
                  ),
                  counterText: '',
                  contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 8,
                child: Text(
                  '$used/$_maxChars',
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 12,
                    color: AppColors.secondaryInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_images.isNotEmpty) ...[
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return _SelectedReviewImage(
                    image: _images[index],
                    onRemove: _sending
                        ? null
                        : () => setState(() => _images.removeAt(index)),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _sending || _images.length >= _maxImages
                    ? null
                    : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                label: Text('Фото ${_images.length}/$_maxImages'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryInk,
                  side: const BorderSide(color: Color(0xFFD9D9DB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _sending ? null : _submit,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryInk,
                side: const BorderSide(color: Color(0xFFD9D9DB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
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

class _SelectedReviewImage extends StatelessWidget {
  const _SelectedReviewImage({required this.image, required this.onRemove});

  final XFile image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 82,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(image.path), fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black.withValues(alpha: 0.58),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyComposerContext extends StatelessWidget {
  const _ReplyComposerContext({required this.review, required this.onCancel});

  final RouteReview review;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('review-reply-composer-context'),
      decoration: BoxDecoration(
        color: AppColors.controlSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 3,
              decoration: const BoxDecoration(
                color: AppColors.primaryInk,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ответ для ${review.authorDisplayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 12,
                        height: 1.25,
                        color: AppColors.secondaryInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Отменить ответ',
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewMediaGrid extends StatelessWidget {
  const _ReviewMediaGrid({
    required this.media,
    required this.config,
    required this.onOpen,
  });

  final List<RouteReviewMedia> media;
  final AppConfig config;
  final ValueChanged<RouteReviewMedia> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in media)
              SizedBox(
                width: width,
                height: 108,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Semantics(
                        button: true,
                        label: 'Открыть фото отзыва',
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onOpen(item),
                            child: Image(
                              image: AppImages.imageProvider(
                                resolvedUrl: AppImages.resolveMediaUrl(
                                  config,
                                  item.url,
                                ),
                                assetFallback: AppImages.coastPineTwilight,
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, _) => const ColoredBox(
                                color: AppColors.controlSurface,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.secondaryInk,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PublishedReplyContext extends StatelessWidget {
  const _PublishedReplyContext({required this.reply});

  final RouteReviewReply reply;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('published-review-reply-${reply.reviewId}'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.controlSurface,
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: AppColors.primaryInk, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.authorDisplayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            reply.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 12,
              height: 1.3,
              color: AppColors.secondaryInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewGalleryDialog extends StatefulWidget {
  const _ReviewGalleryDialog({
    required this.media,
    required this.config,
    required this.initialIndex,
  });

  final List<RouteReviewMedia> media;
  final AppConfig config;
  final int initialIndex;

  @override
  State<_ReviewGalleryDialog> createState() => _ReviewGalleryDialogState();
}

class _ReviewGalleryDialogState extends State<_ReviewGalleryDialog> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('review-photo-fullscreen'),
      color: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.media.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) {
              final item = widget.media[index];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image(
                    image: AppImages.imageProvider(
                      resolvedUrl: AppImages.resolveMediaUrl(
                        widget.config,
                        item.url,
                      ),
                      assetFallback: AppImages.coastPineTwilight,
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: IconButton.filled(
                  tooltip: 'Закрыть',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
          if (widget.media.length > 1)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.media.length}',
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewCard extends ConsumerStatefulWidget {
  const _ReviewCard({
    required this.kind,
    required this.review,
    required this.onReply,
    this.pending = false,
    this.canDelete = false,
    super.key,
  });

  final ReviewEntityKind kind;
  final RouteReview review;
  final VoidCallback onReply;
  final bool pending;
  final bool canDelete;

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final review = widget.review;
    final score = '${review.rating}';
    final avatar = AppImages.resolveMediaUrl(config, review.authorAvatarUrl);
    final media = review.media;
    return Opacity(
      opacity: widget.pending ? 0.72 : 1,
      child: Container(
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
            if (widget.pending)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'На модерации',
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
                    resolvedUrl: avatar,
                    assetFallback: AppImages.travelerPortrait,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.authorDisplayName,
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
                      Text(
                        review.authorRankTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          color: AppColors.secondaryInk,
                        ),
                      ),
                    ],
                  ),
                ),
                for (var index = 0; index < 5; index++)
                  Icon(
                    index < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: index < review.rating
                        ? AppColors.rating
                        : AppColors.secondaryInk,
                  ),
                const SizedBox(width: 6),
                Text(
                  score,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.primaryInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (review.replyTo case final reply?) ...[
              _PublishedReplyContext(reply: reply),
              const SizedBox(height: 10),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                const bodyStyle = TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: AppColors.secondaryInk,
                );
                final painter = TextPainter(
                  text: const TextSpan(style: bodyStyle),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 4,
                )..text = TextSpan(text: review.body, style: bodyStyle);
                painter.layout(maxWidth: constraints.maxWidth);
                final expandable =
                    painter.didExceedMaxLines || media.length > 2;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSize(
                      duration: AppMotion.emphasized,
                      curve: AppMotion.standard,
                      alignment: Alignment.topCenter,
                      child: Text(
                        review.body,
                        maxLines: _expanded ? null : 4,
                        overflow: _expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: bodyStyle,
                      ),
                    ),
                    if (media.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      AnimatedSize(
                        duration: AppMotion.emphasized,
                        curve: AppMotion.standard,
                        alignment: Alignment.topCenter,
                        child: _ReviewMediaGrid(
                          media: _expanded ? media : media.take(2).toList(),
                          config: config,
                          onOpen: (item) => _openGallery(media, item),
                        ),
                      ),
                    ],
                    if (expandable) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Text(
                          _expanded
                              ? 'Свернуть отзыв'
                              : 'Читать отзыв полностью',
                          style: AppTypography.button.copyWith(
                            fontSize: 13,
                            color: AppColors.primaryInk,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                GestureDetector(
                  onTap: widget.onReply,
                  child: Text(
                    'Ответить',
                    style: AppTypography.button.copyWith(
                      fontSize: 13,
                      color: AppColors.primaryInk,
                    ),
                  ),
                ),
                if (widget.canDelete) ...[
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () => unawaited(_confirmDelete(context, ref)),
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
        ),
      ),
    );
  }

  void _openGallery(List<RouteReviewMedia> media, RouteReviewMedia selected) {
    final initialIndex = media.indexWhere((item) => item.id == selected.id);
    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: Colors.black,
        useSafeArea: false,
        builder: (_) => _ReviewGalleryDialog(
          media: media,
          config: ref.read(appConfigProvider),
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить отзыв?'),
          content: const Text(
            'Отзыв исчезнет из списка. Это действие нельзя отменить.',
          ),
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
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await deleteEntityReview(
        ref,
        kind: widget.kind,
        entityId: widget.review.routeId,
        reviewId: widget.review.id,
      );
      invalidateEntityReviews(ref, widget.kind, widget.review.routeId);
    } on AppFailure catch (failure) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось удалить отзыв')));
    }
  }
}
