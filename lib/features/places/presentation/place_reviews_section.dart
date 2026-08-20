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
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/places/application/place_reviews_providers.dart';
import 'package:tourism_mobile/features/places/data/place_reviews_repository.dart';
import 'package:tourism_mobile/features/routes/data/route_reviews_repository.dart';
import 'package:tourism_mobile/routing/app_router.dart';

enum _PlaceReviewFilter { all, newest, oldest, withPhoto }

class PlaceReviewsSection extends ConsumerStatefulWidget {
  const PlaceReviewsSection({required this.placeId, super.key});

  final String placeId;

  @override
  ConsumerState<PlaceReviewsSection> createState() =>
      _PlaceReviewsSectionState();
}

class _PlaceReviewsSectionState extends ConsumerState<PlaceReviewsSection> {
  final _focus = FocusNode();
  var _filter = _PlaceReviewFilter.all;
  RouteReview? _replyTo;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final published = ref.watch(placeReviewsProvider(widget.placeId));
    final mine = ref.watch(myPlaceReviewsProvider).valueOrNull ?? const [];
    final own = mine.where((review) {
      return review.routeId == widget.placeId &&
          review.replyTo == null &&
          (review.status == 'published' || review.status == 'pending_review');
    }).firstOrNull;
    final selfId = ref.watch(sessionProvider).userId;

    return published.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const SizedBox(
        height: 190,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => _ReviewInlineError(
        onRetry: () {
          ref
            ..invalidate(placeReviewsProvider(widget.placeId))
            ..invalidate(myPlaceReviewsProvider);
        },
      ),
      data: (page) {
        final items = _filtered([
          for (final review in page.items)
            if (review.id != own?.id) review,
        ]);
        final pending = [
          for (final review in mine)
            if (review.routeId == widget.placeId &&
                review.status == 'pending_review' &&
                review.id != own?.id &&
                !page.items.any((published) => published.id == review.id))
              review,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryInk,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.rating,
                        size: 17,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        page.averageRating
                                ?.toStringAsFixed(1)
                                .replaceAll('.', ',') ??
                            '—',
                        style: AppTypography.button.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  page.ratingCount == 0
                      ? 'Пока нет отзывов'
                      : '${page.ratingCount} отзывов',
                  style: AppTypography.sectionAction,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (own == null || _replyTo != null) ...[
              _PlaceReviewComposer(
                placeId: widget.placeId,
                focusNode: _focus,
                replyTo: _replyTo,
                onDone: () => setState(() => _replyTo = null),
              ),
              const SizedBox(height: 14),
            ],
            if (own != null) ...[
              const Text('Ваш отзыв', style: AppTypography.button),
              const SizedBox(height: 8),
              _PlaceReviewCard(
                review: own,
                pending: own.status == 'pending_review',
                canDelete: _canDelete(own, selfId),
                onReply: () => _startReply(own),
              ),
              const SizedBox(height: 14),
            ],
            AppFilterChipBar(
              labels: const ['Все', 'Новые', 'Старые', 'С фото'],
              selected: switch (_filter) {
                _PlaceReviewFilter.all => 'Все',
                _PlaceReviewFilter.newest => 'Новые',
                _PlaceReviewFilter.oldest => 'Старые',
                _PlaceReviewFilter.withPhoto => 'С фото',
              },
              onSelected: (label) => setState(() {
                _filter = switch (label) {
                  'Новые' => _PlaceReviewFilter.newest,
                  'Старые' => _PlaceReviewFilter.oldest,
                  'С фото' => _PlaceReviewFilter.withPhoto,
                  _ => _PlaceReviewFilter.all,
                };
              }),
            ),
            const SizedBox(height: 12),
            for (final review in [...pending, ...items]) ...[
              _PlaceReviewCard(
                review: review,
                pending: review.status == 'pending_review',
                canDelete: _canDelete(review, selfId),
                onReply: () => _startReply(review),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  void _startReply(RouteReview review) {
    setState(() => _replyTo = review);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  List<RouteReview> _filtered(List<RouteReview> input) {
    return switch (_filter) {
      _PlaceReviewFilter.all => input,
      _PlaceReviewFilter.newest => [
        ...input,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      _PlaceReviewFilter.oldest => [
        ...input,
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      _PlaceReviewFilter.withPhoto =>
        input.where((review) => review.media.isNotEmpty).toList(),
    };
  }

  static bool _canDelete(RouteReview review, String? selfId) {
    return selfId != null &&
        review.authorUserId == selfId &&
        DateTime.now().toUtc().difference(review.createdAt.toUtc()) <=
            const Duration(hours: 6);
  }
}

class _PlaceReviewComposer extends ConsumerStatefulWidget {
  const _PlaceReviewComposer({
    required this.placeId,
    required this.focusNode,
    required this.replyTo,
    required this.onDone,
  });

  final String placeId;
  final FocusNode focusNode;
  final RouteReview? replyTo;
  final VoidCallback onDone;

  @override
  ConsumerState<_PlaceReviewComposer> createState() =>
      _PlaceReviewComposerState();
}

class _PlaceReviewComposerState extends ConsumerState<_PlaceReviewComposer> {
  final _controller = TextEditingController();
  final _images = <XFile>[];
  var _rating = 5;
  var _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final picked = await ImagePicker().pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 86,
        limit: 6 - _images.length,
        requestFullMetadata: false,
      );
      final accepted = <XFile>[];
      for (final image in picked) {
        if (await image.length() <= 10 * 1024 * 1024) accepted.add(image);
      }
      if (mounted) setState(() => _images.addAll(accepted));
    } on Object {
      if (mounted) _message('Не удалось выбрать фотографии');
    }
  }

  Future<void> _submit() async {
    if (!ref.read(sessionProvider).isAuthenticated) {
      unawaited(context.pushNamed(AppRouteNames.authIdentity));
      return;
    }
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(placeReviewsRepositoryProvider)
          .submit(
            placeId: widget.placeId,
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
      widget.onDone();
      ref
        ..invalidate(placeReviewsProvider(widget.placeId))
        ..invalidate(myPlaceReviewsProvider);
      if (mounted) _message('Отзыв отправлен на модерацию');
    } on AppFailure catch (error) {
      if (mounted) _message(error.message);
    } on Object {
      if (mounted) _message('Не удалось отправить отзыв');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.replyTo case final reply?) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.controlSurface,
                borderRadius: BorderRadius.circular(10),
                border: const Border(left: BorderSide(width: 3)),
              ),
              child: Text(
                'Ответ для ${reply.authorDisplayName}\n${reply.body}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.settingsRowSubtitle,
              ),
            ),
            const SizedBox(height: 10),
          ],
          const Text('Ваш отзыв:', style: AppTypography.button),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => setState(() => _rating = i),
                  child: Icon(
                    i <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.rating,
                    size: 30,
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Очистить',
                onPressed: () => setState(() {
                  _controller.clear();
                  _images.clear();
                  _rating = 5;
                }),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          TextField(
            controller: _controller,
            focusNode: widget.focusNode,
            minLines: 4,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Поделитесь впечатлениями о месте',
              filled: true,
              fillColor: AppColors.pageSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (_, index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.file(
                        File(_images[index].path),
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        iconSize: 15,
                        onPressed: () =>
                            setState(() => _images.removeAt(index)),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _sending || _images.length >= 6 ? null : _pick,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text('Добавить фото ${_images.length}/6'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: _sending ? null : _submit,
              child: Text(_sending ? 'Отправка…' : 'Отправить'),
            ),
          ),
        ],
      ),
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _PlaceReviewCard extends ConsumerStatefulWidget {
  const _PlaceReviewCard({
    required this.review,
    required this.pending,
    required this.canDelete,
    required this.onReply,
  });

  final RouteReview review;
  final bool pending;
  final bool canDelete;
  final VoidCallback onReply;

  @override
  ConsumerState<_PlaceReviewCard> createState() => _PlaceReviewCardState();
}

class _PlaceReviewCardState extends ConsumerState<_PlaceReviewCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final config = ref.watch(appConfigProvider);
    return Opacity(
      opacity: widget.pending ? 0.72 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.pending)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('На модерации', style: AppTypography.sectionAction),
              ),
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundImage: AppImages.imageProvider(
                    resolvedUrl: AppImages.resolveMediaUrl(
                      config,
                      review.authorAvatarUrl,
                    ),
                    assetFallback: AppImages.travelerPortrait,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.authorDisplayName,
                        style: AppTypography.settingsRowTitle,
                      ),
                      Text(
                        review.authorRankTitle,
                        style: AppTypography.settingsRowSubtitle,
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < 5; i++)
                  Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 15,
                    color: AppColors.rating,
                  ),
              ],
            ),
            if (review.replyTo case final reply?) ...[
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.controlSurface,
                  borderRadius: BorderRadius.circular(9),
                  border: const Border(left: BorderSide(width: 3)),
                ),
                child: Text(
                  '${reply.authorDisplayName}\n${reply.body}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.settingsRowSubtitle,
                ),
              ),
            ],
            const SizedBox(height: 9),
            AnimatedSize(
              duration: AppMotion.normal,
              child: Text(
                review.body,
                maxLines: _expanded ? null : 4,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: AppTypography.routeMetadata.copyWith(
                  color: AppColors.secondaryInk,
                  height: 1.4,
                ),
              ),
            ),
            if (review.media.isNotEmpty) ...[
              const SizedBox(height: 9),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _expanded
                      ? review.media.length
                      : review.media.length.clamp(0, 3),
                  separatorBuilder: (_, _) => const SizedBox(width: 7),
                  itemBuilder: (_, index) => GestureDetector(
                    onTap: () => _openGallery(index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image(
                        width: 108,
                        fit: BoxFit.cover,
                        image: AppImages.imageProvider(
                          resolvedUrl: AppImages.resolveMediaUrl(
                            config,
                            review.media[index].url,
                          ),
                          assetFallback: AppImages.coastPineTwilight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (review.body.length > 220 || review.media.length > 3) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Свернуть отзыв' : 'Читать отзыв полностью',
                  style: AppTypography.button.copyWith(fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onReply,
                  child: const Text('Ответить'),
                ),
                if (widget.canDelete)
                  TextButton(
                    onPressed: () => unawaited(_delete()),
                    child: const Text('Удалить'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openGallery(int initialIndex) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: Colors.black,
        useSafeArea: false,
        builder: (dialogContext) => Material(
          color: Colors.black,
          child: Stack(
            children: [
              PageView.builder(
                controller: PageController(initialPage: initialIndex),
                itemCount: widget.review.media.length,
                itemBuilder: (_, index) => InteractiveViewer(
                  maxScale: 4,
                  child: Center(
                    child: Image(
                      fit: BoxFit.contain,
                      image: AppImages.imageProvider(
                        resolvedUrl: AppImages.resolveMediaUrl(
                          ref.read(appConfigProvider),
                          widget.review.media[index].url,
                        ),
                        assetFallback: AppImages.coastPineTwilight,
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton.filled(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить отзыв?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(placeReviewsRepositoryProvider)
          .delete(placeId: widget.review.routeId, reviewId: widget.review.id);
      ref
        ..invalidate(placeReviewsProvider(widget.review.routeId))
        ..invalidate(myPlaceReviewsProvider);
    } on AppFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _ReviewInlineError extends StatelessWidget {
  const _ReviewInlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Не удалось загрузить отзывы'),
      ),
    );
  }
}
