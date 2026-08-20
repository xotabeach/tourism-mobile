import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/theme/app_fonts.dart';
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
        final ratingLabel = page.averageRating == null
            ? '—'
            : page.averageRating!.toStringAsFixed(1).replaceAll('.', ',');
        final topLabel = page.ratingCount == 0
            ? 'Пока нет отзывов'
            : 'ТОП ${page.ratingCount}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PlaceRatingRow(rating: ratingLabel, topLabel: topLabel),
            const SizedBox(height: 14),
            if (own == null || _replyTo != null) ...[
              _PlaceReviewComposer(
                placeId: widget.placeId,
                focusNode: _focus,
                replyTo: _replyTo,
                onCancelReply: () => setState(() => _replyTo = null),
                onDone: () => setState(() => _replyTo = null),
              ),
              const SizedBox(height: 14),
            ],
            if (own != null) ...[
              const Text(
                'Ваш отзыв',
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryInk,
                ),
              ),
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
            const SizedBox(height: 14),
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

class _PlaceRatingRow extends StatelessWidget {
  const _PlaceRatingRow({required this.rating, required this.topLabel});

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

class _PlaceReviewComposer extends ConsumerStatefulWidget {
  const _PlaceReviewComposer({
    required this.placeId,
    required this.focusNode,
    required this.replyTo,
    required this.onCancelReply,
    required this.onDone,
  });

  final String placeId;
  final FocusNode focusNode;
  final RouteReview? replyTo;
  final VoidCallback onCancelReply;
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

  static const _maxChars = 500;
  static const _maxImages = 6;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

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
        limit: _maxImages - _images.length,
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
      if (mounted) {
        _message(
          widget.replyTo == null
              ? 'Отзыв отправлен на модерацию'
              : 'Ответ отправлен на модерацию',
        );
      }
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
    final used = _controller.text.characters.length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E4E6)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Ответ для ${reply.authorDisplayName}\n${reply.body}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.secondaryInk,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Отменить ответ',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onCancelReply,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
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
                  hintText: 'Поделитесь впечатлениями о месте',
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
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(_images[index].path),
                        width: 82,
                        height: 82,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _sending
                              ? null
                              : () => setState(() => _images.removeAt(index)),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _sending || _images.length >= _maxImages
                  ? null
                  : _pick,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryInk,
                side: const BorderSide(color: Color(0xFFD9D9DB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Добавить фото или видео'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: _sending ? null : _submit,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryInk,
                side: const BorderSide(color: AppColors.primaryInk),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
                    resolvedUrl: AppImages.resolveMediaUrl(
                      config,
                      review.authorAvatarUrl,
                    ),
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
                  '${review.rating}',
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
            if (review.replyTo case final reply?) ...[
              const SizedBox(height: 10),
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
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.secondaryInk,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            AnimatedSize(
              duration: AppMotion.normal,
              child: Text(
                review.body,
                maxLines: _expanded ? null : 4,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: AppColors.secondaryInk,
                ),
              ),
            ),
            if (media.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _expanded
                      ? media.length
                      : media.length.clamp(0, 3),
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
                            media[index].url,
                          ),
                          assetFallback: AppImages.coastPineTwilight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (review.body.length > 220 || media.length > 3) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Свернуть отзыв' : 'Читать отзыв полностью',
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryInk,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: widget.onReply,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryInk,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Ответить',
                    style: TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.canDelete) ...[
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () => unawaited(_delete()),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.secondaryInk,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Удалить',
                      style: TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
