import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/domain/articles_repository.dart';

/// Where a block's picked image is in the two-phase upload the backend
/// requires: the block row is created by the article save, the file goes up
/// in its own request afterwards, and only that second half is retried when
/// the connection drops.
enum BlockUploadStatus { none, waitingForSave, uploading, failed }

class EditorBlock {
  const EditorBlock({
    required this.localId,
    required this.type,
    this.serverId,
    this.text = '',
    this.caption,
    this.listStyle,
    this.imageUrl,
    this.pendingImagePath,
    this.uploadStatus = BlockUploadStatus.none,
  });

  /// Stable across reorders and saves — the server id only exists after the
  /// first save, so the list cannot be keyed on it.
  final String localId;
  final String? serverId;
  final ArticleBlockType type;
  final String text;
  final String? caption;
  final ListStyle? listStyle;
  final String? imageUrl;
  final String? pendingImagePath;
  final BlockUploadStatus uploadStatus;

  bool get hasContent => switch (type) {
    ArticleBlockType.text || ArticleBlockType.quote => text.trim().isNotEmpty,
    ArticleBlockType.list => listItems.isNotEmpty,
    ArticleBlockType.image => imageUrl != null || pendingImagePath != null,
    ArticleBlockType.divider => true,
  };

  List<String> get listItems => [
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  EditorBlock copyWith({
    String? serverId,
    String? text,
    String? caption,
    bool clearCaption = false,
    ListStyle? listStyle,
    String? imageUrl,
    bool clearImageUrl = false,
    String? pendingImagePath,
    bool clearPendingImagePath = false,
    BlockUploadStatus? uploadStatus,
  }) {
    return EditorBlock(
      localId: localId,
      type: type,
      serverId: serverId ?? this.serverId,
      text: text ?? this.text,
      caption: clearCaption ? null : caption ?? this.caption,
      listStyle: listStyle ?? this.listStyle,
      imageUrl: clearImageUrl ? null : imageUrl ?? this.imageUrl,
      pendingImagePath: clearPendingImagePath
          ? null
          : pendingImagePath ?? this.pendingImagePath,
      uploadStatus: uploadStatus ?? this.uploadStatus,
    );
  }

  ArticleBlockDraft toDraft() {
    return ArticleBlockDraft(
      // Без id сервер не знает, что это тот же самый блок, пересоздаёт его
      // пустым и удаляет загруженную картинку: фото жило до первой же правки
      // статьи (баг 2026-09-03).
      id: serverId,
      blockType: type,
      textContent: switch (type) {
        ArticleBlockType.text ||
        ArticleBlockType.quote => text.trim().isEmpty ? null : text.trim(),
        ArticleBlockType.list =>
          listItems.isEmpty ? null : listItems.join('\n'),
        ArticleBlockType.image || ArticleBlockType.divider => null,
      },
      caption:
          type == ArticleBlockType.quote &&
              (caption?.trim().isNotEmpty ?? false)
          ? caption!.trim()
          : null,
      listStyle: type == ArticleBlockType.list
          ? (listStyle ?? ListStyle.bullet)
          : null,
    );
  }
}

class ArticleEditorState {
  const ArticleEditorState({
    this.articleId,
    this.status = ArticleStatus.draft,
    this.title = '',
    this.tags = const {},
    this.blocks = const [],
    this.relatedRouteId,
    this.relatedRouteName,
    this.relatedPlaceId,
    this.relatedPlaceName,
    this.loading = false,
    this.saving = false,
    this.savedAt,
    this.submitting = false,
    this.submitted = false,
    this.message,
    this.messageSerial = 0,
  });

  final String? articleId;
  final ArticleStatus status;
  final String title;
  final Set<String> tags;
  final List<EditorBlock> blocks;
  final String? relatedRouteId;
  final String? relatedRouteName;
  final String? relatedPlaceId;
  final String? relatedPlaceName;
  final bool loading;
  final bool saving;
  final DateTime? savedAt;
  final bool submitting;
  final bool submitted;

  /// One-shot notice channel, read via [messageSerial] the same way
  /// `RoutePublishState` does it — a repeated identical message still fires.
  final String? message;
  final int messageSerial;

  bool get hasAnyContent =>
      title.trim().isNotEmpty || blocks.any((block) => block.hasContent);

  /// Submitting only makes sense before the article has been through
  /// moderation. One already in the queue has nothing to submit, and
  /// editing a published one re-queues it by itself.
  bool get canSubmitAtAll =>
      status == ArticleStatus.draft || status == ArticleStatus.rejected;

  /// The backend rejects an empty article on submit, so the button is gated
  /// on the same rule instead of waiting for the 400.
  bool get canSubmit =>
      canSubmitAtAll &&
      !submitting &&
      title.trim().isNotEmpty &&
      blocks.any((block) => block.hasContent) &&
      blocks.every(
        (block) => block.uploadStatus != BlockUploadStatus.uploading,
      );

  int get imageCount =>
      blocks.where((block) => block.type == ArticleBlockType.image).length;

  ArticleEditorState copyWith({
    String? articleId,
    ArticleStatus? status,
    String? title,
    Set<String>? tags,
    List<EditorBlock>? blocks,
    String? relatedRouteId,
    String? relatedRouteName,
    String? relatedPlaceId,
    String? relatedPlaceName,
    bool clearRelated = false,
    bool? loading,
    bool? saving,
    DateTime? savedAt,
    bool? submitting,
    bool? submitted,
    String? message,
    int? messageSerial,
  }) {
    return ArticleEditorState(
      articleId: articleId ?? this.articleId,
      status: status ?? this.status,
      title: title ?? this.title,
      tags: tags ?? this.tags,
      blocks: blocks ?? this.blocks,
      relatedRouteId: clearRelated
          ? null
          : relatedRouteId ?? this.relatedRouteId,
      relatedRouteName: clearRelated
          ? null
          : relatedRouteName ?? this.relatedRouteName,
      relatedPlaceId: clearRelated
          ? null
          : relatedPlaceId ?? this.relatedPlaceId,
      relatedPlaceName: clearRelated
          ? null
          : relatedPlaceName ?? this.relatedPlaceName,
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      savedAt: savedAt ?? this.savedAt,
      submitting: submitting ?? this.submitting,
      submitted: submitted ?? this.submitted,
      message: message,
      messageSerial: messageSerial ?? this.messageSerial,
    );
  }
}

/// `articleId == null` opens a brand-new draft.
final articleEditorControllerProvider = StateNotifierProvider.autoDispose
    .family<ArticleEditorController, ArticleEditorState, String?>((
      ref,
      articleId,
    ) {
      return ArticleEditorController(
        ref.watch(articlesRepositoryProvider),
        articleId: articleId,
        onSaved: () {
          ref.invalidate(myArticlesProvider);
          if (articleId != null) {
            ref.invalidate(articleDetailsProvider(articleId));
          }
        },
      );
    });

class ArticleEditorController extends StateNotifier<ArticleEditorState> {
  ArticleEditorController(
    this._repository, {
    required String? articleId,
    this.onSaved,
    this.autosaveDelay = const Duration(seconds: 2),
  }) : super(
         ArticleEditorState(articleId: articleId, loading: articleId != null),
       ) {
    if (articleId != null) {
      unawaited(_load(articleId));
    }
  }

  final ArticlesRepository _repository;
  final VoidCallback? onSaved;
  final Duration autosaveDelay;

  Timer? _autosave;
  var _localIdSeed = 0;
  var _messageSerial = 0;

  @override
  void dispose() {
    _autosave?.cancel();
    super.dispose();
  }

  String _nextLocalId() => 'block-${_localIdSeed++}';

  Future<void> _load(String articleId) async {
    try {
      final article = await _repository.getArticle(articleId);
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        status: article.status,
        title: article.title,
        tags: article.tags.toSet(),
        relatedRouteId: article.relatedRouteId,
        relatedPlaceId: article.relatedPlaceId,
        blocks: [
          for (final block in article.sortedBlocks)
            EditorBlock(
              localId: _nextLocalId(),
              serverId: block.id,
              type: block.blockType,
              text: block.textContent ?? '',
              caption: block.caption,
              listStyle: block.listStyle,
              imageUrl: block.imageUrl,
            ),
        ],
      );
    } on AppFailure catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        message: error.message,
        messageSerial: ++_messageSerial,
      );
    } on Object {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        message: 'Не удалось открыть статью',
        messageSerial: ++_messageSerial,
      );
    }
  }

  void _touch() {
    _autosave?.cancel();
    _autosave = Timer(autosaveDelay, () => unawaited(save()));
  }

  void setTitle(String value) {
    state = state.copyWith(title: value);
    _touch();
  }

  void toggleTag(String tag) {
    final tags = {...state.tags};
    if (!tags.remove(tag)) {
      if (tags.length >= ArticleLimits.maxTagsPerArticle) {
        return;
      }
      tags.add(tag);
    }
    state = state.copyWith(tags: tags);
    _touch();
  }

  void addBlock(ArticleBlockType type) {
    if (state.blocks.length >= ArticleLimits.maxBlocksPerArticle) {
      state = state.copyWith(
        message:
            'В статье не больше ${ArticleLimits.maxBlocksPerArticle} блоков',
        messageSerial: ++_messageSerial,
      );
      return;
    }
    if (type == ArticleBlockType.image &&
        state.imageCount >= ArticleLimits.maxImagesPerArticle) {
      state = state.copyWith(
        message:
            'Не больше ${ArticleLimits.maxImagesPerArticle} изображений на статью',
        messageSerial: ++_messageSerial,
      );
      return;
    }
    state = state.copyWith(
      blocks: [
        ...state.blocks,
        EditorBlock(
          localId: _nextLocalId(),
          type: type,
          listStyle: type == ArticleBlockType.list ? ListStyle.bullet : null,
        ),
      ],
    );
    _touch();
  }

  void removeBlock(String localId) {
    state = state.copyWith(
      blocks: [
        for (final block in state.blocks)
          if (block.localId != localId) block,
      ],
    );
    _touch();
  }

  void reorderBlocks(int oldIndex, int newIndex) {
    final blocks = [...state.blocks];
    final moved = blocks.removeAt(oldIndex);
    blocks.insert(newIndex, moved);
    state = state.copyWith(blocks: blocks);
    _touch();
  }

  void editBlockText(String localId, String text) {
    _updateBlock(localId, (block) => block.copyWith(text: text));
  }

  void editBlockCaption(String localId, String caption) {
    _updateBlock(localId, (block) => block.copyWith(caption: caption));
  }

  void setListStyle(String localId, ListStyle style) {
    _updateBlock(localId, (block) => block.copyWith(listStyle: style));
  }

  void _updateBlock(
    String localId,
    EditorBlock Function(EditorBlock) update, {
    bool touch = true,
  }) {
    state = state.copyWith(
      blocks: [
        for (final block in state.blocks)
          if (block.localId == localId) update(block) else block,
      ],
    );
    if (touch) {
      _touch();
    }
  }

  void attachRoute({required String id, required String name}) {
    state = state
        .copyWith(clearRelated: true)
        .copyWith(relatedRouteId: id, relatedRouteName: name);
    _touch();
  }

  void attachPlace({required String id, required String name}) {
    state = state
        .copyWith(clearRelated: true)
        .copyWith(relatedPlaceId: id, relatedPlaceName: name);
    _touch();
  }

  void clearAttachment() {
    state = state.copyWith(clearRelated: true);
    _touch();
  }

  /// Picks a local file for an image block. The bytes only leave the device
  /// after the next save, which is what mints the block's server id.
  void attachImage(String localId, String filePath) {
    _updateBlock(
      localId,
      (block) => block.copyWith(
        pendingImagePath: filePath,
        uploadStatus: BlockUploadStatus.waitingForSave,
        clearImageUrl: true,
      ),
    );
  }

  Future<void> save() async {
    _autosave?.cancel();
    if (state.saving || state.submitting || !state.hasAnyContent) {
      return;
    }
    // A draft with no title cannot be persisted (the backend requires one),
    // so autosave quietly waits instead of throwing a validation error at
    // someone who is still typing.
    final title = state.title.trim();
    if (title.isEmpty) {
      return;
    }
    state = state.copyWith(saving: true);
    try {
      final saved = state.articleId == null
          ? await _repository.createDraft(
              title: title,
              relatedRouteId: state.relatedRouteId,
              relatedPlaceId: state.relatedPlaceId,
              tags: state.tags.toList(),
              blocks: [for (final block in state.blocks) block.toDraft()],
            )
          : await _repository.updateDraft(
              state.articleId!,
              title: title,
              relatedRouteId: state.relatedRouteId,
              relatedPlaceId: state.relatedPlaceId,
              tags: state.tags.toList(),
              blocks: [for (final block in state.blocks) block.toDraft()],
            );
      if (!mounted) return;
      _adoptServerIds(saved);
      state = state.copyWith(
        articleId: saved.id,
        status: saved.status,
        saving: false,
        savedAt: DateTime.now(),
      );
      onSaved?.call();
      await _uploadPendingImages();
    } on AppFailure catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        saving: false,
        message: error.message,
        messageSerial: ++_messageSerial,
      );
    } on Object {
      if (!mounted) return;
      state = state.copyWith(
        saving: false,
        message: 'Не удалось сохранить черновик',
        messageSerial: ++_messageSerial,
      );
    }
  }

  /// The server rebuilds the block list on every save, so the ids come back
  /// fresh — matched by position, which is the only thing both sides agree
  /// on.
  void _adoptServerIds(Article saved) {
    final serverBlocks = saved.sortedBlocks;
    state = state.copyWith(
      blocks: [
        for (var index = 0; index < state.blocks.length; index++)
          index < serverBlocks.length
              ? state.blocks[index].copyWith(
                  serverId: serverBlocks[index].id,
                  imageUrl: serverBlocks[index].imageUrl,
                )
              : state.blocks[index],
      ],
    );
  }

  Future<void> _uploadPendingImages() async {
    for (final block in [...state.blocks]) {
      final path = block.pendingImagePath;
      final serverId = block.serverId;
      if (path == null || serverId == null) {
        continue;
      }
      await _uploadOne(block.localId, serverId, path);
    }
  }

  /// Retries just the file, never the whole article — the point of the
  /// two-phase upload.
  Future<void> retryUpload(String localId) async {
    final block = state.blocks.firstWhere((item) => item.localId == localId);
    final path = block.pendingImagePath;
    final serverId = block.serverId;
    if (path == null) {
      return;
    }
    if (serverId == null) {
      await save();
      return;
    }
    await _uploadOne(localId, serverId, path);
  }

  Future<void> _uploadOne(String localId, String serverId, String path) async {
    final articleId = state.articleId;
    if (articleId == null) {
      return;
    }
    _updateBlock(
      localId,
      (block) => block.copyWith(uploadStatus: BlockUploadStatus.uploading),
      touch: false,
    );
    try {
      final uploaded = await _repository.uploadBlockImage(
        articleId,
        serverId,
        path,
      );
      if (!mounted) return;
      _updateBlock(
        localId,
        (block) => block.copyWith(
          imageUrl: uploaded.imageUrl,
          clearPendingImagePath: true,
          uploadStatus: BlockUploadStatus.none,
        ),
        touch: false,
      );
    } on Object {
      if (!mounted) return;
      _updateBlock(
        localId,
        (block) => block.copyWith(uploadStatus: BlockUploadStatus.failed),
        touch: false,
      );
      state = state.copyWith(
        message: 'Изображение не загрузилось — можно повторить',
        messageSerial: ++_messageSerial,
      );
    }
  }

  Future<void> submitForReview() async {
    await save();
    if (!mounted) return;
    final articleId = state.articleId;
    if (articleId == null || !state.canSubmit) {
      return;
    }
    state = state.copyWith(submitting: true);
    try {
      final submitted = await _repository.submitForReview(articleId);
      if (!mounted) return;
      state = state.copyWith(
        submitting: false,
        submitted: true,
        status: submitted.status,
        message: 'Статья отправлена на модерацию',
        messageSerial: ++_messageSerial,
      );
      onSaved?.call();
    } on AppFailure catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        submitting: false,
        message: error.message,
        messageSerial: ++_messageSerial,
      );
    } on Object {
      if (!mounted) return;
      state = state.copyWith(
        submitting: false,
        message: 'Не удалось отправить статью',
        messageSerial: ++_messageSerial,
      );
    }
  }
}
