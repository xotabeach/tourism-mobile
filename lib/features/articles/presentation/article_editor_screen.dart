import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
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

  /// Раскрыт максимум один блок: иначе список снова разрастается и теряется
  /// то, ради чего плитки сворачивали.
  String? _expandedBlockId;

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
        centerTitle: true,
        title: Text(
          widget.articleId == null ? 'Новая статья' : 'Редактор статьи',
          style: AppTypography.chip.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Тап по пустому месту и смахивание списка убирают клавиатуру: без
      // этого на телефоне она закрывала пол-экрана и снять её было нечем.
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
              collapsedCount: 5,
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
                proxyDecorator: (child, _, animation) {
                  // Плитка «поднимается»: чуть увеличивается и получает тень,
                  // чтобы было видно, что она оторвана от списка.
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, inner) {
                      final t = Curves.easeOut.transform(animation.value);
                      return Transform.scale(
                        scale: 1 + 0.03 * t,
                        child: Material(
                          color: Colors.transparent,
                          elevation: 8 * t,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(14),
                          child: inner,
                        ),
                      );
                    },
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  final block = state.blocks[index];
                  // Ручкой служат сами точки внутри плитки, а не вся она:
                  // раньше долгое нажатие ловил InkWell, которым открывается
                  // блок, и перенос вообще не начинался.
                  return Padding(
                    key: ValueKey(block.localId),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BlockAppear(
                      child: _BlockEditorTile(
                        dragIndex: index,
                        expanded: _expandedBlockId == block.localId,
                        onToggleExpanded: () => setState(() {
                          _expandedBlockId = _expandedBlockId == block.localId
                              ? null
                              : block.localId;
                          FocusManager.instance.primaryFocus?.unfocus();
                        }),
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
            // Панель добавления и нижний бар живут в конце списка, а не
            // закреплены снизу: в канвасе они часть страницы, а закреплённые
            // съедали треть экрана. Новые блоки добавляются в конец, так что
            // после добавления человек и так уже внизу.
            const SizedBox(height: 22),
            _AddBlockBar(
              onAdd: (type) {
                controller.addBlock(type);
                // Только что добавленный блок раскрываем сразу: иначе после
                // нажатия «Текст» человек видит свёрнутую строку и не понимает,
                // куда писать.
                final added = ref.read(provider).blocks.lastOrNull;
                if (added != null) {
                  setState(() => _expandedBlockId = added.localId);
                }
              },
            ),
            const SizedBox(height: 28),
            const Divider(height: 1, thickness: 1, color: AppColors.hairline),
            const SizedBox(height: 18),
            _EditorBottomBar(state: state, controller: controller),
          ],
        ),
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
            fontSize: 17,
            fontWeight: FontWeight.w500,
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
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$length/${ArticleLimits.maxTitleLength}',
            style: AppTypography.settingsRowSubtitle.copyWith(fontSize: 11),
          ),
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
    final hasRoute = state.relatedRouteId != null;
    final hasPlace = state.relatedPlaceId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Взаимоисключающий выбор: на бэкенде CHECK-констрейнт разрешает
        // либо маршрут, либо место, поэтому и в интерфейсе это радио, а не
        // одна кнопка «выбрать что-нибудь».
        Row(
          children: [
            Expanded(
              child: _AttachKindOption(
                label: 'Маршрут',
                selected: hasRoute,
                onTap: () => unawaited(_pick(context, AttachKind.route)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AttachKindOption(
                label: 'Место',
                selected: hasPlace,
                onTap: () => unawaited(_pick(context, AttachKind.place)),
              ),
            ),
          ],
        ),
        if (attachedName != null) ...[
          const SizedBox(height: 10),
          _AttachedChip(
            label: attachedName,
            onRemove: controller.clearAttachment,
          ),
        ],
      ],
    );
  }

  Future<void> _pick(BuildContext context, AttachKind kind) async {
    final attachment = await showArticleAttachPicker(
      context,
      initialKind: kind,
    );
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

/// Вариант привязки: маршрут или место. Значения сняты с канваса —
/// выбранный: рамка 1.5 #171719 и «залитая» точка, невыбранный: 1 #D9D9DB.
class _AttachKindOption extends StatelessWidget {
  const _AttachKindOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primaryInk : const Color(0xFFD9D9DB),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryInk
                        : const Color(0xFFD9D9DB),
                    width: selected ? 5 : 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.chip.copyWith(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? AppColors.primaryInk
                        : AppColors.secondaryInk,
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

/// Выбранный маршрут или место — серый чип с крестиком.
class _AttachedChip extends StatelessWidget {
  const _AttachedChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 7, 8, 7),
        decoration: BoxDecoration(
          color: AppColors.controlSurface,
          borderRadius: BorderRadius.circular(AppRadii.capsule),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.chip.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryInk,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Убрать привязку',
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.secondaryInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ручка перетаскивания: две колонки по три точки, как нарисовано в канвасе.
/// Материаловская `drag_indicator` рисует другой узор и заметно темнее.
/// Появление блока: короткое проявление со сдвигом вверх. Без него новый
/// блок возникает мгновенно и посреди списка это выглядит как сбой отрисовки.
class _BlockAppear extends StatefulWidget {
  const _BlockAppear({required this.child});

  final Widget child;

  @override
  State<_BlockAppear> createState() => _BlockAppearState();
}

class _BlockAppearState extends State<_BlockAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.emphasized,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standard,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

class _DragDots extends StatelessWidget {
  const _DragDots();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 14,
      height: 20,
      child: CustomPaint(painter: _DragDotsPainter()),
    );
  }
}

class _DragDotsPainter extends CustomPainter {
  const _DragDotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFD1D2D4);
    for (final dy in const [4.0, 10.0, 16.0]) {
      canvas.drawCircle(Offset(4, dy), 1.6, paint);
      canvas.drawCircle(Offset(10, dy), 1.6, paint);
    }
  }

  @override
  bool shouldRepaint(_DragDotsPainter oldDelegate) => false;
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
    required this.dragIndex,
    required this.expanded,
    required this.onToggleExpanded,
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

  final int dragIndex;
  final bool expanded;
  final VoidCallback onToggleExpanded;
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
          // Свёрнутая плитка — как в канвасе: перетаскивание, тип, одна
          // строка предпросмотра, корзина. Тап по ней разворачивает
          // редактирование на месте.
          Semantics(
            button: true,
            expanded: expanded,
            label: '${_label(block.type)}, блок статьи',
            child: InkWell(
              key: ValueKey('block-tile-${block.localId}'),
              onTap: onToggleExpanded,
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: dragIndex,
                    child: const Padding(
                      // Расширяем зону захвата: сами точки 14×20 — мелкая
                      // цель для пальца.
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: _DragDots(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ..._leading(context, ref),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _label(block.type),
                          style: AppTypography.settingsRowSubtitle.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.02,
                          ),
                        ),
                        if (!expanded) ...[
                          const SizedBox(height: 3),
                          Text(
                            _preview(block),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.settingsRowTitle.copyWith(
                              fontSize: 13,
                              fontStyle: block.type == ArticleBlockType.quote
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Удалить блок',
                    visualDensity: VisualDensity.compact,
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
          // Разворачивание и сворачивание анимируются: скачок высоты в
          // списке из нескольких блоков читается как «что-то дёрнулось».
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: AnimatedOpacity(
              duration: AppMotion.normal,
              opacity: expanded ? 1 : 0,
              child: expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _body(context, ref),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
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

  /// Значок слева от подписи: миниатюра у картинки, синяя черта у цитаты,
  /// иконка у списка — ровно как в канвасе. У текста и разделителя его нет.
  List<Widget> _leading(BuildContext context, WidgetRef ref) {
    switch (block.type) {
      case ArticleBlockType.image:
        final config = ref.watch(appConfigProvider);
        final hasImage =
            block.imageUrl != null || block.pendingImagePath != null;
        return [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.controlSurface,
              borderRadius: BorderRadius.circular(8),
              image: hasImage && block.imageUrl != null
                  ? DecorationImage(
                      image: articleImageProvider(
                        config: config,
                        url: block.imageUrl,
                        fallbackSeed: block.localId,
                      ),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
        ];
      case ArticleBlockType.quote:
        return [
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.accentBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
        ];
      case ArticleBlockType.list:
        return const [
          Icon(
            Icons.format_list_bulleted_rounded,
            size: 20,
            color: AppColors.primaryInk,
          ),
          SizedBox(width: 10),
        ];
      case ArticleBlockType.text:
      case ArticleBlockType.divider:
        return const [];
    }
  }

  /// Одна строка под типом блока в свёрнутом виде.
  static String _preview(EditorBlock block) {
    final text = block.text.trim();
    return switch (block.type) {
      ArticleBlockType.divider => 'Разрыв между частями',
      ArticleBlockType.image =>
        block.imageUrl != null || block.pendingImagePath != null
            ? 'Изображение добавлено'
            : 'Фото не выбрано',
      ArticleBlockType.list =>
        text.isEmpty
            ? 'Пункты не заданы'
            : '${text.split('\n').where((line) => line.trim().isNotEmpty).length} пункта',
      _ => text.isEmpty ? 'Пусто — нажмите, чтобы написать' : text,
    };
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
      child: Padding(
        padding: EdgeInsets.zero,
        // Строкой, как в канвасе: индикатор слева, кнопка справа. Индикатор
        // гибкий и обрезается — раньше он был Expanded и утаскивал строку в
        // перенос, из-за чего кнопка выезжала за край на узком экране.
        child: Row(
          children: [
            // Обе части гибкие, но кнопка получает большую долю: при крупном
            // системном шрифте строка иначе выезжает за край. Индикатор —
            // вторичный, ему и ужиматься первым.
            Flexible(child: _SaveIndicator(state: state)),
            const SizedBox(width: 12),
            // Кнопка по содержимому, а не по доле строки: с flex она
            // растягивалась на весь остаток, и подпись внутри выглядела
            // сдвинутой относительно рамки.
            //
            // Для статьи на модерации и уже опубликованной кнопки нет:
            // первой отправлять нечего, вторая уйдёт на проверку сама, как
            // только правки сохранятся.
            if (state.canSubmitAtAll)
              Flexible(
                fit: FlexFit.loose,
                child: OutlinedButton(
                  onPressed: state.canSubmit
                      ? () => unawaited(controller.submitForReview())
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryInk,
                    side: const BorderSide(
                      color: AppColors.primaryInk,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.capsule),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    textStyle: AppTypography.chip.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(
                    state.submitting ? 'Отправка…' : 'Отправить на модерацию',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
    // Подпись обрезается, а не распирает строку: индикатор делит её с кнопкой
    // «Отправить на модерацию», и при крупном шрифте место кончается первым
    // именно здесь.
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
          Flexible(
            child: Text(
              'Сохранение…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.settingsRowSubtitle,
            ),
          ),
        ],
      );
    }
    if (state.savedAt == null) {
      return const Text(
        'Черновик',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.settingsRowSubtitle,
      );
    }
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_rounded, size: 15, color: AppColors.secondaryInk),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Сохранено',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.settingsRowSubtitle,
          ),
        ),
      ],
    );
  }
}
