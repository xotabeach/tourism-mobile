import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/domain/content_tags.dart';
import 'package:tourism_mobile/features/articles/application/article_editor_controller.dart';
import 'package:tourism_mobile/features/articles/data/article_image_picker.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/domain/articles_repository.dart';
import 'package:tourism_mobile/features/articles/presentation/article_attach_picker_sheet.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/article_images.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/tag_chip_picker.dart';

/// Block editor (G.9). Blocks are held locally and pushed as one list on
/// every save — the backend rebuilds them wholesale — while an image block's
/// file travels separately, so a failed upload retries by itself.
class ArticleEditorScreen extends ConsumerStatefulWidget {
  const ArticleEditorScreen({this.articleId, super.key});

  static const routePath = '/articles/editor';

  /// `null` starts a new draft.
  final String? articleId;

  @override
  ConsumerState<ArticleEditorScreen> createState() =>
      _ArticleEditorScreenState();
}

class _ArticleEditorScreenState extends ConsumerState<ArticleEditorScreen> {
  final _titleController = TextEditingController();
  final _blockControllers = <String, TextEditingController>{};
  final _captionControllers = <String, TextEditingController>{};

  @override
  void dispose() {
    _titleController.dispose();
    for (final controller in _blockControllers.values) {
      controller.dispose();
    }
    for (final controller in _captionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(
    Map<String, TextEditingController> pool,
    String key,
    String initial,
  ) {
    return pool.putIfAbsent(key, () => TextEditingController(text: initial));
  }

  @override
  Widget build(BuildContext context) {
    final provider = articleEditorControllerProvider(widget.articleId);
    ref.listen(provider, (previous, next) {
      if (next.message != null &&
          next.messageSerial != previous?.messageSerial) {
        showAppNotice(context, next.message!);
      }
      if (_titleController.text != next.title &&
          !_titleController.selection.isValid) {
        _titleController.text = next.title;
      }
      if (next.submitted && (previous?.submitted ?? false) == false) {
        context.pop();
      }
    });
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    if (state.loading) {
      return const Scaffold(
        backgroundColor: AppColors.pageSurface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      appBar: AppBar(
        backgroundColor: AppColors.pageSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () async {
            await controller.save();
            if (context.mounted) {
              context.pop();
            }
          },
        ),
        title: Text(
          widget.articleId == null ? 'Новая статья' : 'Редактор статьи',
          style: AppTypography.chip.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          32,
        ),
        children: [
          _TitleField(
            controller: _titleController,
            onChanged: controller.setTitle,
            length: state.title.characters.length,
          ),
          const SizedBox(height: 22),
          const Text(
            'Теги · до ${ArticleLimits.maxTagsPerArticle}',
            style: AppTypography.settingsRowTitle,
          ),
          const SizedBox(height: 10),
          TagChipPicker(
            tags: articleTags,
            selected: state.tags,
            onToggle: controller.toggleTag,
            maxSelected: ArticleLimits.maxTagsPerArticle,
          ),
          const SizedBox(height: 22),
          const Text('Привязать к', style: AppTypography.settingsRowTitle),
          const SizedBox(height: 10),
          _AttachmentRow(state: state, controller: controller),
          const SizedBox(height: 22),
          const Text('Содержание', style: AppTypography.settingsRowTitle),
          const SizedBox(height: 10),
          if (state.blocks.isEmpty)
            const _EmptyBlocksHint()
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: state.blocks.length,
              onReorderItem: controller.reorderBlocks,
              proxyDecorator: (child, _, animation) =>
                  FadeTransition(opacity: animation, child: child),
              itemBuilder: (context, index) {
                final block = state.blocks[index];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(block.localId),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BlockEditorTile(
                      block: block,
                      textController: _controllerFor(
                        _blockControllers,
                        block.localId,
                        block.text,
                      ),
                      captionController: _controllerFor(
                        _captionControllers,
                        block.localId,
                        block.caption ?? '',
                      ),
                      onTextChanged: (value) =>
                          controller.editBlockText(block.localId, value),
                      onCaptionChanged: (value) =>
                          controller.editBlockCaption(block.localId, value),
                      onListStyleChanged: (style) =>
                          controller.setListStyle(block.localId, style),
                      onPickImage: () => unawaited(_pickImage(block.localId)),
                      onRetryUpload: () =>
                          unawaited(controller.retryUpload(block.localId)),
                      onRemove: () {
                        _blockControllers.remove(block.localId)?.dispose();
                        _captionControllers.remove(block.localId)?.dispose();
                        controller.removeBlock(block.localId);
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      // The add-block bar is pinned rather than living at the end of the
      // list: in a long article you would otherwise scroll to the bottom
      // every time you wanted one more block.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AddBlockBar(onAdd: controller.addBlock),
          _EditorBottomBar(state: state, controller: controller),
        ],
      ),
    );
  }

  Future<void> _pickImage(String localId) async {
    final provider = articleEditorControllerProvider(widget.articleId);
    final controller = ref.read(provider.notifier);
    try {
      final picked = await ImagePickerArticleImagePicker(
        ImagePicker(),
      ).pickFromGallery();
      if (picked == null) {
        return;
      }
      controller.attachImage(localId, picked.path);
      // Saving now is what mints the block's server id, which the upload
      // needs — so an image the author just picked starts uploading without
      // waiting out the autosave debounce.
      await controller.save();
    } on FormatException catch (error) {
      if (mounted) {
        showAppNotice(context, error.message);
      }
    } on Object {
      if (mounted) {
        showAppNotice(context, 'Не удалось выбрать изображение');
      }
    }
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField({
    required this.controller,
    required this.onChanged,
    required this.length,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLength: ArticleLimits.maxTitleLength,
          maxLines: 2,
          minLines: 1,
          style: AppTypography.routeTitle.copyWith(
            fontSize: 18,
            color: AppColors.primaryInk,
          ),
          decoration: InputDecoration(
            hintText: 'Заголовок статьи',
            filled: true,
            fillColor: const Color(0xFFF0F0F0),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: Color(0xFFD9D9DB)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$length/${ArticleLimits.maxTitleLength}',
          style: AppTypography.settingsRowSubtitle,
        ),
      ],
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.state, required this.controller});

  final ArticleEditorState state;
  final ArticleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final attachedName = state.relatedRouteName ?? state.relatedPlaceName;
    final hasAttachment =
        state.relatedRouteId != null || state.relatedPlaceId != null;
    if (!hasAttachment) {
      return OutlinedButton.icon(
        onPressed: () => unawaited(_pick(context)),
        icon: const Icon(Icons.add_link_rounded, size: 20),
        label: const Text('Выбрать маршрут или место'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryInk,
          side: const BorderSide(color: Color(0xFFD9D9DB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.capsule),
          ),
          minimumSize: const Size.fromHeight(46),
        ),
      );
    }
    return Row(
      children: [
        Icon(
          state.relatedRouteId != null
              ? Icons.route_rounded
              : Icons.place_rounded,
          size: 20,
          color: AppColors.primaryInk,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            attachedName ?? 'Выбрано',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.settingsRowTitle.copyWith(fontSize: 14),
          ),
        ),
        TextButton(
          onPressed: () => unawaited(_pick(context)),
          child: const Text('Изменить'),
        ),
        IconButton(
          tooltip: 'Убрать привязку',
          onPressed: controller.clearAttachment,
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final attachment = await showArticleAttachPicker(context);
    if (attachment == null) {
      return;
    }
    if (attachment.kind == AttachKind.route) {
      controller.attachRoute(id: attachment.id, name: attachment.name);
    } else {
      controller.attachPlace(id: attachment.id, name: attachment.name);
    }
  }
}

class _EmptyBlocksHint extends StatelessWidget {
  const _EmptyBlocksHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: const Color(0xFFEDEDEE)),
      ),
      child: const Text(
        'Добавьте первый блок — текст, фото, цитату, список или разделитель.',
        textAlign: TextAlign.center,
        style: AppTypography.settingsRowSubtitle,
      ),
    );
  }
}

class _BlockEditorTile extends ConsumerWidget {
  const _BlockEditorTile({
    required this.block,
    required this.textController,
    required this.captionController,
    required this.onTextChanged,
    required this.onCaptionChanged,
    required this.onListStyleChanged,
    required this.onPickImage,
    required this.onRetryUpload,
    required this.onRemove,
  });

  final EditorBlock block;
  final TextEditingController textController;
  final TextEditingController captionController;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<String> onCaptionChanged;
  final ValueChanged<ListStyle> onListStyleChanged;
  final VoidCallback onPickImage;
  final VoidCallback onRetryUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: const Color(0xFFEDEDEE)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.drag_indicator_rounded,
                size: 20,
                color: Color(0xFFC7CDD3),
              ),
              const SizedBox(width: 6),
              Text(
                _label(block.type),
                style: AppTypography.settingsRowSubtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.02,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Удалить блок',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
          ..._body(context, ref),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, WidgetRef ref) {
    switch (block.type) {
      case ArticleBlockType.divider:
        return const [Divider(height: 12, color: Color(0xFFE3E3E5))];
      case ArticleBlockType.image:
        return [
          _ImageBody(
            block: block,
            onPick: onPickImage,
            onRetry: onRetryUpload,
            ref: ref,
          ),
        ];
      case ArticleBlockType.text:
      case ArticleBlockType.quote:
      case ArticleBlockType.list:
        return [
          TextField(
            controller: textController,
            onChanged: onTextChanged,
            minLines: block.type == ArticleBlockType.text ? 3 : 2,
            maxLines: 8,
            maxLength: ArticleLimits.maxTextBlockLength,
            style: TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 14,
              height: 1.4,
              fontStyle: block.type == ArticleBlockType.quote
                  ? FontStyle.italic
                  : FontStyle.normal,
              color: AppColors.primaryInk,
            ),
            decoration: InputDecoration(
              hintText: switch (block.type) {
                ArticleBlockType.quote => 'Текст цитаты',
                ArticleBlockType.list => 'По пункту на строку',
                _ => 'Текст абзаца',
              },
              filled: true,
              fillColor: const Color(0xFFF0F0F0),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.tile),
                borderSide: const BorderSide(color: Color(0xFFD9D9DB)),
              ),
            ),
          ),
          if (block.type == ArticleBlockType.quote) ...[
            const SizedBox(height: 8),
            TextField(
              controller: captionController,
              onChanged: onCaptionChanged,
              maxLength: ArticleLimits.maxQuoteCaptionLength,
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 13,
                color: AppColors.secondaryInk,
              ),
              decoration: InputDecoration(
                hintText: 'Подпись (необязательно)',
                filled: true,
                fillColor: const Color(0xFFF0F0F0),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  borderSide: const BorderSide(color: Color(0xFFD9D9DB)),
                ),
              ),
            ),
          ],
          if (block.type == ArticleBlockType.list) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (final style in ListStyle.values) ...[
                  if (style != ListStyle.values.first) const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      style == ListStyle.bullet ? 'Маркеры' : 'Нумерация',
                    ),
                    selected: (block.listStyle ?? ListStyle.bullet) == style,
                    onSelected: (_) => onListStyleChanged(style),
                  ),
                ],
              ],
            ),
          ],
        ];
    }
  }

  static String _label(ArticleBlockType type) => switch (type) {
    ArticleBlockType.text => 'ТЕКСТ',
    ArticleBlockType.image => 'КАРТИНКА',
    ArticleBlockType.quote => 'ЦИТАТА',
    ArticleBlockType.list => 'СПИСОК',
    ArticleBlockType.divider => 'РАЗДЕЛИТЕЛЬ',
  };
}

class _ImageBody extends StatelessWidget {
  const _ImageBody({
    required this.block,
    required this.onPick,
    required this.onRetry,
    required this.ref,
  });

  final EditorBlock block;
  final VoidCallback onPick;
  final VoidCallback onRetry;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final localPath = block.pendingImagePath;
    final preview = localPath != null
        ? Image.file(File(localPath), fit: BoxFit.cover)
        : block.imageUrl != null
        ? Image(
            image: articleImageProvider(
              config: config,
              url: block.imageUrl,
              fallbackSeed: block.localId,
            ),
            fit: BoxFit.cover,
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preview != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.tile),
            child: AspectRatio(aspectRatio: 4 / 3, child: preview),
          )
        else
          GestureDetector(
            onTap: onPick,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.controlSurface,
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              child: const Center(
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 28,
                  color: AppColors.secondaryInk,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            switch (block.uploadStatus) {
              BlockUploadStatus.uploading => const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Загрузка…', style: AppTypography.settingsRowSubtitle),
                ],
              ),
              BlockUploadStatus.failed => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Не загрузилось',
                    style: AppTypography.settingsRowSubtitle.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
              BlockUploadStatus.waitingForSave => const Text(
                'Загрузится после сохранения',
                style: AppTypography.settingsRowSubtitle,
              ),
              BlockUploadStatus.none => const SizedBox.shrink(),
            },
            const Spacer(),
            if (preview != null)
              TextButton(onPressed: onPick, child: const Text('Заменить')),
          ],
        ),
      ],
    );
  }
}

class _AddBlockBar extends StatelessWidget {
  const _AddBlockBar({required this.onAdd});

  final ValueChanged<ArticleBlockType> onAdd;

  @override
  Widget build(BuildContext context) {
    const entries = [
      (ArticleBlockType.text, Icons.notes_rounded, 'Текст'),
      (ArticleBlockType.image, Icons.image_outlined, 'Фото'),
      (ArticleBlockType.quote, Icons.format_quote_rounded, 'Цитата'),
      (ArticleBlockType.list, Icons.format_list_bulleted_rounded, 'Список'),
      (ArticleBlockType.divider, Icons.horizontal_rule_rounded, 'Разделитель'),
    ];
    return Container(
      color: AppColors.pageSurface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final (type, icon, label) in entries)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: AppColors.elevatedSurface,
                  shape: const CircleBorder(
                    side: BorderSide(color: Color(0xFFD9D9DB)),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onAdd(type),
                    child: SizedBox.square(
                      dimension: 46,
                      child: Icon(icon, size: 20, color: AppColors.primaryInk),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: 62,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTypography.settingsRowSubtitle.copyWith(
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EditorBottomBar extends StatelessWidget {
  const _EditorBottomBar({required this.state, required this.controller});

  final ArticleEditorState state;
  final ArticleEditorController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.elevatedSurface,
          border: Border(top: BorderSide(color: Color(0xFFEDEDEE))),
        ),
        // Stacked rather than side by side: "Отправить на модерацию" is long
        // enough to overflow a row on a narrow phone or at a larger text scale.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _SaveIndicator(state: state),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: state.canSubmit
                  ? () => unawaited(controller.submitForReview())
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryInk,
                side: const BorderSide(color: AppColors.primaryInk, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.capsule),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                state.submitting ? 'Отправка…' : 'Отправить на модерацию',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.state});

  final ArticleEditorState state;

  @override
  Widget build(BuildContext context) {
    if (state.saving) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Сохранение…', style: AppTypography.settingsRowSubtitle),
        ],
      );
    }
    if (state.savedAt == null) {
      return const Text('Черновик', style: AppTypography.settingsRowSubtitle);
    }
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_rounded, size: 15, color: AppColors.secondaryInk),
        SizedBox(width: 6),
        Text('Сохранено', style: AppTypography.settingsRowSubtitle),
      ],
    );
  }
}
