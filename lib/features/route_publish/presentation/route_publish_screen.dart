import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/components/app_brand_bar.dart';
import 'package:tourism_mobile/core/design/components/app_edge_back_gesture.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/domain/content_tags.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/core/media/photo_editor_screen.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/route_publish/application/route_publish_controller.dart';
import 'package:tourism_mobile/features/route_publish/data/route_media_picker.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/presentation/publish_route_design_tokens.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_place_picker_sheet.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_preview.dart';

class RoutePublishScreen extends ConsumerStatefulWidget {
  const RoutePublishScreen({
    this.mode = RoutePublishMode.production,
    super.key,
  });

  const RoutePublishScreen.golden({super.key}) : mode = RoutePublishMode.golden;

  static const routePath = '/publish';
  final RoutePublishMode mode;

  @override
  ConsumerState<RoutePublishScreen> createState() => _RoutePublishScreenState();
}

class _RoutePublishScreenState extends ConsumerState<RoutePublishScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _titleFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  final _scrollController = ScrollController();
  final _galleryController = ScrollController();
  double _appBarProgress = 0;

  RoutePublishMode get _mode => widget.mode;

  @override
  void initState() {
    super.initState();
    final initial = _mode == RoutePublishMode.golden
        ? RouteDraft.golden()
        : const RouteDraft();
    _titleController = TextEditingController(text: initial.title);
    _descriptionController = TextEditingController(text: initial.description);
    _scrollController.addListener(_syncAppBarFromScroll);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocus.dispose();
    _descriptionFocus.dispose();
    _scrollController
      ..removeListener(_syncAppBarFromScroll)
      ..dispose();
    _galleryController.dispose();
    super.dispose();
  }

  void _syncAppBarFromScroll() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    final progress = ((_scrollController.offset - 20) / 64).clamp(0.0, 1.0);
    if ((progress - _appBarProgress).abs() < 0.001) {
      return;
    }
    setState(() => _appBarProgress = progress);
  }

  void _goBack() {
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final provider = routePublishControllerProvider(_mode);
    ref.listen(provider, (previous, next) {
      if (!_titleFocus.hasFocus && _titleController.text != next.draft.title) {
        _titleController.text = next.draft.title;
      }
      if (!_descriptionFocus.hasFocus &&
          _descriptionController.text != next.draft.description) {
        _descriptionController.text = next.draft.description;
      }
      if (next.message != null &&
          next.messageSerial != previous?.messageSerial) {
        showAppNotice(context, next.message!);
      }
    });
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    final content = AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Scaffold(
          key: const ValueKey('route-publish-viewport'),
          backgroundColor: PublishRouteDesignTokens.background,
          resizeToAvoidBottomInset: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final designWidth = constraints.maxWidth.clamp(
                      0.0,
                      PublishRouteDesignTokens.designWidth,
                    );
                    final scale =
                        designWidth / PublishRouteDesignTokens.designWidth;
                    double u(double value) => value * scale;
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: designWidth,
                        child: GestureDetector(
                          onTap: () =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          behavior: HitTestBehavior.translucent,
                          child: ScrollConfiguration(
                            behavior: const _NoGlowScrollBehavior(),
                            child: SingleChildScrollView(
                              key: const ValueKey('route-publish-scroll'),
                              controller: _scrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.viewPaddingOf(context).bottom +
                                    (_mode == RoutePublishMode.production
                                        ? u(40)
                                        : 0),
                              ),
                              child: KeyedSubtree(
                                key: const ValueKey('route-publish-capture'),
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: u(18),
                                    right: u(17),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: u(27)),
                                      _FixedText(
                                        height: u(29),
                                        text: 'Опубликовать маршрут:',
                                        style: _style(
                                          u,
                                          22,
                                          FontWeight.w600,
                                          PublishRouteDesignTokens.dark,
                                          1.15,
                                        ),
                                      ),
                                      SizedBox(height: u(15)),
                                      if (state.draft.media.isNotEmpty) ...[
                                        RouteMediaCarousel(
                                          u: u,
                                          items: state.draft.media,
                                          controller: _galleryController,
                                          onReorder: controller.reorderMedia,
                                          onRemove: controller.removeMedia,
                                          onEdit: (item) => _showMediaActions(
                                            item,
                                            controller,
                                          ),
                                        ),
                                        SizedBox(height: u(14)),
                                      ],
                                      AddRouteMediaTile(
                                        u: u,
                                        loading: state.isPickingMedia,
                                        onTap: () =>
                                            _showMediaPicker(controller),
                                      ),
                                      if (state.mediaError != null)
                                        _ErrorText(
                                          u: u,
                                          text: state.mediaError!,
                                        ),
                                      SizedBox(height: u(20)),
                                      RouteBasicInformationSection(
                                        u: u,
                                        titleController: _titleController,
                                        descriptionController:
                                            _descriptionController,
                                        titleFocus: _titleFocus,
                                        descriptionFocus: _descriptionFocus,
                                        titleError: state.titleError,
                                        descriptionError:
                                            state.descriptionError,
                                        onTitleChanged: controller.setTitle,
                                        onDescriptionChanged:
                                            controller.setDescription,
                                      ),
                                      SizedBox(height: u(20)),
                                      RouteLocationSection(
                                        u: u,
                                        title: 'Стартовая точка:',
                                        semanticsLabel: 'Стартовая точка',
                                        location: state.draft.start,
                                        error: state.startError,
                                        onTap: () => _pickLocation(
                                          title: 'Выберите стартовую точку',
                                          onSelected: controller.setStart,
                                        ),
                                      ),
                                      SizedBox(height: u(19)),
                                      RouteLocationSection(
                                        u: u,
                                        title: 'Финишная точка:',
                                        semanticsLabel: 'Финишная точка',
                                        location: state.draft.finish,
                                        error: state.finishError,
                                        headerToCardGap: 15,
                                        onTap: () => _pickLocation(
                                          title: 'Выберите финишную точку',
                                          onSelected: controller.setFinish,
                                        ),
                                      ),
                                      SizedBox(height: u(19)),
                                      RouteStopsSection(
                                        u: u,
                                        stops: state.draft.stops,
                                        recalculating: state.isRecalculating,
                                        onAdd: () => _pickLocation(
                                          title: 'Добавить остановку',
                                          onSelected: controller.addStop,
                                        ),
                                        onEdit: (index) =>
                                            _showStopActions(index, controller),
                                        onReorder: controller.reorderStop,
                                      ),
                                      SizedBox(height: u(6.5)),
                                      RouteMapPreviewCard(
                                        u: u,
                                        golden:
                                            _mode == RoutePublishMode.golden,
                                        draft: state.draft,
                                        onTap: () => _pickLocation(
                                          title: 'Добавить точку на маршрут',
                                          onSelected: controller.addStop,
                                        ),
                                      ),
                                      if (state.routeError != null)
                                        _ErrorText(
                                          u: u,
                                          text: state.routeError!,
                                        ),
                                      SizedBox(height: u(20)),
                                      RouteFiltersSection(
                                        u: u,
                                        filters: state.draft.filters,
                                        onToggle: controller.toggleFilter,
                                        onAdd: () =>
                                            _showFilterPicker(controller),
                                      ),
                                      SizedBox(height: u(20)),
                                      TravelPaceSelector(
                                        u: u,
                                        value: state.draft.pace,
                                        onChanged: controller.setPace,
                                      ),
                                      SizedBox(height: u(19)),
                                      RouteDifficultySelector(
                                        u: u,
                                        value: state.draft.difficulty,
                                        onChanged: controller.setDifficulty,
                                      ),
                                      SizedBox(height: u(18)),
                                      PublishRouteActions(
                                        u: u,
                                        publishing: state.isPublishing,
                                        saving: state.isSaving,
                                        onPublish: () => _publish(controller),
                                        onSave: controller.saveDraft,
                                      ),
                                      SizedBox(height: u(26)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_mode == RoutePublishMode.production)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: AppScrollBrandBar(
                    topInset: MediaQuery.paddingOf(context).top,
                    progress: _appBarProgress,
                    onBack: _goBack,
                  ),
                ),
              if (_mode == RoutePublishMode.production &&
                  state.availableDraft != null)
                Positioned.fill(
                  child: _DraftRecoveryOverlay(
                    draft: state.availableDraft!,
                    onContinue: controller.continueDraft,
                    onStartNew: controller.startNewDraft,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return _mode == RoutePublishMode.production
        ? AppEdgeBackGesture(onBack: _goBack, child: content)
        : content;
  }

  Future<void> _publish(RoutePublishController controller) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final id = await controller.publish();
    if (id != null && mounted) {
      final userId = ref.read(sessionProvider).userId;
      if (userId != null && userId.isNotEmpty) {
        ref.invalidate(publicProfileProvider(userId));
      }
      context.go('/my-routes');
    }
  }

  Future<void> _pickLocation({
    required String title,
    required ValueChanged<RouteLocation> onSelected,
  }) async {
    final location = await showRoutePlacePicker(context, title: title);
    if (location != null) {
      onSelected(location);
    }
  }

  Future<void> _showMediaPicker(RoutePublishController controller) async {
    final source = await showModalBottomSheet<RouteMediaSource>(
      context: context,
      backgroundColor: PublishRouteDesignTokens.background,
      showDragHandle: true,
      builder: (context) => const _MediaPickerSheet(),
    );
    if (source != null && mounted) {
      await controller.addMedia(
        source,
        crop: (path) => cropPickedPhoto(
          context,
          sourcePath: path,
          shape: PhotoCropShape.wide,
          title: 'Фото маршрута',
        ),
      );
    }
  }

  Future<void> _showMediaActions(
    RouteMediaItem item,
    RoutePublishController controller,
  ) async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: PublishRouteDesignTokens.background,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline_rounded),
          title: const Text('Удалить медиа'),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (remove ?? false) {
      controller.removeMedia(item.id);
    }
  }

  Future<void> _showStopActions(
    int index,
    RoutePublishController controller,
  ) async {
    final action = await showModalBottomSheet<_StopAction>(
      context: context,
      backgroundColor: PublishRouteDesignTokens.background,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_location_alt_outlined),
              title: const Text('Изменить остановку'),
              onTap: () => Navigator.pop(context, _StopAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Удалить остановку'),
              onTap: () => Navigator.pop(context, _StopAction.remove),
            ),
          ],
        ),
      ),
    );
    if (action == _StopAction.remove) {
      controller.removeStop(index);
    } else if (action == _StopAction.edit && mounted) {
      await _pickLocation(
        title: 'Изменить остановку',
        onSelected: (location) => controller.replaceStop(index, location),
      );
    }
  }

  Future<void> _showFilterPicker(RoutePublishController controller) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: PublishRouteDesignTokens.background,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final selected = ref.watch(
            routePublishControllerProvider(
              _mode,
            ).select((value) => value.draft.filters),
          );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in routeTags)
                    FilterChip(
                      label: Text(filter),
                      selected: selected.contains(filter),
                      onSelected: (_) => controller.toggleFilter(filter),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DraftRecoveryOverlay extends StatelessWidget {
  const _DraftRecoveryOverlay({
    required this.draft,
    required this.onContinue,
    required this.onStartNew,
  });

  final RouteDraft draft;
  final VoidCallback onContinue;
  final Future<void> Function() onStartNew;

  String get _updatedLabel {
    final value = draft.updatedAt?.toLocal();
    if (value == null) {
      return 'Сохранён на этом устройстве';
    }
    String two(int number) => number.toString().padLeft(2, '0');
    return 'Изменён ${two(value.day)}.${two(value.month)}.${value.year} '
        'в ${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final title = draft.title.trim().isEmpty
        ? 'Маршрут без названия'
        : draft.title.trim();
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ModalBarrier(color: Color(0x73000000), dismissible: false),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Semantics(
                namesRoute: true,
                label: 'Найден сохранённый черновик маршрута',
                child: Container(
                  key: const ValueKey('route-draft-choice'),
                  constraints: const BoxConstraints(maxWidth: 390),
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  decoration: BoxDecoration(
                    color: PublishRouteDesignTokens.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: PublishRouteDesignTokens.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: PublishRouteDesignTokens.selectedLightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_note_rounded,
                          color: PublishRouteDesignTokens.primaryBlue,
                          size: 27,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'У вас есть черновик',
                        textAlign: TextAlign.center,
                        style: PublishRouteDesignTokens.rubik(
                          fontSize: 21,
                          weight: FontWeight.w600,
                          color: PublishRouteDesignTokens.dark,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: PublishRouteDesignTokens.rubik(
                          fontSize: 16,
                          weight: FontWeight.w500,
                          color: PublishRouteDesignTokens.dark,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _updatedLabel,
                        textAlign: TextAlign.center,
                        style: PublishRouteDesignTokens.rubik(
                          fontSize: 13,
                          weight: FontWeight.w400,
                          color: PublishRouteDesignTokens.secondaryText,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _DraftChoiceButton(
                        key: const ValueKey('route-draft-continue'),
                        label: 'Продолжить',
                        filled: true,
                        onTap: onContinue,
                      ),
                      const SizedBox(height: 9),
                      _DraftChoiceButton(
                        key: const ValueKey('route-draft-start-new'),
                        label: 'Начать заново',
                        filled: false,
                        onTap: () => unawaited(onStartNew()),
                      ),
                    ],
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

class _DraftChoiceButton extends StatelessWidget {
  const _DraftChoiceButton({
    required this.label,
    required this.filled,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(26);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: filled
            ? PublishRouteDesignTokens.dark
            : PublishRouteDesignTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: filled
              ? BorderSide.none
              : const BorderSide(color: PublishRouteDesignTokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: PublishRouteDesignTokens.rubik(
                  fontSize: 16,
                  weight: FontWeight.w500,
                  color: filled ? Colors.white : PublishRouteDesignTokens.dark,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _StopAction { edit, remove }

TextStyle _style(
  double Function(double) u,
  double size,
  FontWeight weight,
  Color color,
  double height,
) {
  return PublishRouteDesignTokens.rubik(
    fontSize: u(size),
    weight: weight,
    color: color,
    height: height,
  );
}

class _FixedText extends StatelessWidget {
  const _FixedText({
    required this.height,
    required this.text,
    required this.style,
  });

  final double height;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(text, maxLines: 1, style: style),
      ),
    );
  }
}

class RouteMediaCarousel extends StatelessWidget {
  const RouteMediaCarousel({
    required this.u,
    required this.items,
    required this.controller,
    required this.onReorder,
    required this.onRemove,
    required this.onEdit,
    super.key,
  });

  final double Function(double) u;
  final List<RouteMediaItem> items;
  final ScrollController controller;
  final void Function(int, int) onReorder;
  final ValueChanged<String> onRemove;
  final ValueChanged<RouteMediaItem> onEdit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Медиа маршрута, ${items.length} элементов',
      child: SizedBox(
        key: const ValueKey('route-media-carousel'),
        height: u(214),
        child: items.isEmpty
            ? const SizedBox.expand()
            : OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: u(416),
                child: SizedBox(
                  width: u(416),
                  child: ReorderableListView.builder(
                    scrollController: controller,
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    onReorderItem: onReorder,
                    proxyDecorator: (child, _, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Padding(
                        key: ValueKey(item.id),
                        padding: EdgeInsets.only(
                          right: index == items.length - 1 ? 0 : u(9),
                        ),
                        child: ReorderableDelayedDragStartListener(
                          index: index,
                          child: Semantics(
                            button: true,
                            label: index == 0
                                ? 'Обложка маршрута'
                                : 'Медиа ${index + 1}',
                            child: SizedBox(
                              width: u(162),
                              height: u(214),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: GestureDetector(
                                      onTap: () => onEdit(item),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          u(8),
                                        ),
                                        child: _RouteMediaPreview(item: item),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: u(8),
                                    right: u(8),
                                    child: Semantics(
                                      button: true,
                                      label: 'Удалить медиа ${index + 1}',
                                      child: Material(
                                        color: PublishRouteDesignTokens.dark
                                            .withValues(alpha: 0.72),
                                        shape: const CircleBorder(),
                                        clipBehavior: Clip.antiAlias,
                                        child: InkWell(
                                          key: ValueKey(
                                            'route-media-remove-${item.id}',
                                          ),
                                          onTap: () => onRemove(item.id),
                                          child: SizedBox.square(
                                            dimension: u(28),
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: u(17),
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}

class _RouteMediaPreview extends StatelessWidget {
  const _RouteMediaPreview({required this.item});

  final RouteMediaItem item;

  @override
  Widget build(BuildContext context) {
    if (item.kind == RouteMediaKind.video) {
      return const ColoredBox(
        color: PublishRouteDesignTokens.dark,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
          ],
        ),
      );
    }
    return item.isAsset
        ? Image.asset(item.path, fit: BoxFit.cover)
        : Image.file(
            File(item.path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: PublishRouteDesignTokens.fieldBackground,
              child: Icon(Icons.broken_image_outlined),
            ),
          );
  }
}

class AddRouteMediaTile extends StatelessWidget {
  const AddRouteMediaTile({
    required this.u,
    required this.loading,
    required this.onTap,
    super.key,
  });

  final double Function(double) u;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(u(12));
    return Semantics(
      button: true,
      label: 'Добавить фото или видео',
      child: Material(
        key: const ValueKey('route-add-media'),
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: radius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Ink(
            width: double.infinity,
            height: u(89),
            decoration: BoxDecoration(
              color: PublishRouteDesignTokens.fieldBackground,
              borderRadius: radius,
              border: Border.all(
                color: PublishRouteDesignTokens.border,
                width: u(1),
              ),
            ),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: u(11),
                  child: SizedBox.square(
                    dimension: u(39),
                    child: loading
                        ? Padding(
                            padding: EdgeInsets.all(u(8)),
                            child: CircularProgressIndicator(
                              strokeWidth: u(2),
                              color: PublishRouteDesignTokens.secondaryText,
                            ),
                          )
                        : CustomPaint(painter: _AddMediaIconPainter(u)),
                  ),
                ),
                Positioned(
                  top: u(61),
                  child: Text(
                    'Добавить фото или видео',
                    style: _style(
                      u,
                      16,
                      FontWeight.w400,
                      PublishRouteDesignTokens.secondaryText,
                      1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddMediaIconPainter extends CustomPainter {
  const _AddMediaIconPainter(this.u);
  final double Function(double) u;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final border = Paint()
      ..color = const Color(0xFFBEBEBE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = u(2);
    canvas.drawCircle(center, (size.shortestSide - u(2)) / 2, border);
    final plus = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = u(2)
      ..strokeCap = StrokeCap.round;
    final half = u(7.5);
    canvas
      ..drawLine(center - Offset(half, 0), center + Offset(half, 0), plus)
      ..drawLine(center - Offset(0, half), center + Offset(0, half), plus);
  }

  @override
  bool shouldRepaint(covariant _AddMediaIconPainter oldDelegate) => false;
}

class RouteBasicInformationSection extends StatelessWidget {
  const RouteBasicInformationSection({
    required this.u,
    required this.titleController,
    required this.descriptionController,
    required this.titleFocus,
    required this.descriptionFocus,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
    this.titleError,
    this.descriptionError,
    super.key,
  });

  final double Function(double) u;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final FocusNode titleFocus;
  final FocusNode descriptionFocus;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onDescriptionChanged;
  final String? titleError;
  final String? descriptionError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FixedText(
          height: u(23),
          text: 'Основная информация:',
          style: _style(
            u,
            20,
            FontWeight.w600,
            PublishRouteDesignTokens.dark,
            1.15,
          ),
        ),
        SizedBox(height: u(13)),
        RouteTitleField(
          u: u,
          controller: titleController,
          focusNode: titleFocus,
          error: titleError,
          onChanged: onTitleChanged,
          onSubmitted: (_) => descriptionFocus.requestFocus(),
        ),
        SizedBox(height: u(9)),
        RouteDescriptionField(
          u: u,
          controller: descriptionController,
          focusNode: descriptionFocus,
          error: descriptionError,
          onChanged: onDescriptionChanged,
        ),
      ],
    );
  }
}

class RouteTitleField extends StatefulWidget {
  const RouteTitleField({
    required this.u,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    this.error,
    super.key,
  });

  final double Function(double) u;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final String? error;

  @override
  State<RouteTitleField> createState() => _RouteTitleFieldState();
}

class _RouteTitleFieldState extends State<RouteTitleField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant RouteTitleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_refresh);
      widget.focusNode.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    final value = widget.controller.text;
    final display = value.isEmpty ? 'Название маршрута' : value;
    final textStyle = _style(
      u,
      15,
      FontWeight.w400,
      value.isEmpty
          ? PublishRouteDesignTokens.secondaryText
          : PublishRouteDesignTokens.dark,
      1,
    );
    final painter = TextPainter(
      text: TextSpan(text: display, style: textStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final counterStyle = _style(
      u,
      15,
      FontWeight.w400,
      const Color(0xFFA6A6A6),
      1,
    );
    final counterPainter = TextPainter(
      text: TextSpan(
        text: '${value.characters.length}/30',
        style: counterStyle,
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final preferred = u(17) + painter.width + u(11);
            final maxLeft = constraints.maxWidth - u(16) - counterPainter.width;
            final counterLeft = preferred.clamp(u(17), maxLeft);
            return SizedBox(
              key: const ValueKey('route-title-field'),
              height: u(41),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: PublishRouteDesignTokens.fieldBackground,
                  borderRadius: BorderRadius.circular(u(12)),
                  border: Border.all(
                    color: widget.error != null
                        ? PublishRouteDesignTokens.error
                        : widget.focusNode.hasFocus
                        ? PublishRouteDesignTokens.primaryBlue
                        : PublishRouteDesignTokens.border,
                    width: u(widget.focusNode.hasFocus ? 1.25 : 1),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        inputFormatters: [LengthLimitingTextInputFormatter(30)],
                        maxLines: 1,
                        textAlignVertical: TextAlignVertical.center,
                        textInputAction: TextInputAction.next,
                        onSubmitted: widget.onSubmitted,
                        onChanged: (value) {
                          widget.onChanged(value);
                          setState(() {});
                        },
                        style: _style(
                          u,
                          15,
                          FontWeight.w400,
                          PublishRouteDesignTokens.dark,
                          1,
                        ),
                        cursorHeight: u(18),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.fromLTRB(
                            u(17),
                            u(12),
                            u(64),
                            u(12),
                          ),
                        ),
                      ),
                    ),
                    if (value.isEmpty)
                      Positioned(
                        left: u(17),
                        top: 0,
                        height: u(41),
                        child: IgnorePointer(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Название маршрута', style: textStyle),
                          ),
                        ),
                      ),
                    Positioned(
                      left: counterLeft,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${value.characters.length}/30',
                          style: counterStyle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (widget.error != null) _ErrorText(u: u, text: widget.error!),
      ],
    );
  }
}

class RouteDescriptionField extends StatefulWidget {
  const RouteDescriptionField({
    required this.u,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.error,
    super.key,
  });

  final double Function(double) u;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String? error;

  @override
  State<RouteDescriptionField> createState() => _RouteDescriptionFieldState();
}

class _RouteDescriptionFieldState extends State<RouteDescriptionField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    final value = widget.controller.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: const ValueKey('route-description-field'),
          height: u(102),
          decoration: BoxDecoration(
            color: PublishRouteDesignTokens.fieldBackground,
            borderRadius: BorderRadius.circular(u(12)),
            border: Border.all(
              color: widget.error != null
                  ? PublishRouteDesignTokens.error
                  : widget.focusNode.hasFocus
                  ? PublishRouteDesignTokens.primaryBlue
                  : PublishRouteDesignTokens.border,
              width: u(widget.focusNode.hasFocus ? 1.25 : 1),
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  inputFormatters: [LengthLimitingTextInputFormatter(500)],
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: widget.focusNode.unfocus,
                  onChanged: (value) {
                    widget.onChanged(value);
                    setState(() {});
                  },
                  style: _style(
                    u,
                    15,
                    FontWeight.w400,
                    PublishRouteDesignTokens.dark,
                    1.15,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.fromLTRB(
                      u(17),
                      u(10),
                      u(16),
                      u(28),
                    ),
                    hintText: 'Описание маршрута',
                    hintStyle: _style(
                      u,
                      15,
                      FontWeight.w400,
                      PublishRouteDesignTokens.secondaryText,
                      1.15,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: u(16),
                bottom: u(10),
                child: Text(
                  '${value.characters.length}/500',
                  style: _style(
                    u,
                    15,
                    FontWeight.w400,
                    const Color(0xFFA6A6A6),
                    1,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.error != null) _ErrorText(u: u, text: widget.error!),
      ],
    );
  }
}

class RouteLocationSection extends StatelessWidget {
  const RouteLocationSection({
    required this.u,
    required this.title,
    required this.semanticsLabel,
    required this.location,
    required this.onTap,
    this.error,
    this.headerToCardGap = 14,
    super.key,
  });

  final double Function(double) u;
  final String title;
  final String semanticsLabel;
  final RouteLocation? location;
  final VoidCallback onTap;
  final String? error;
  final double headerToCardGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(u: u, title: title, onAction: onTap),
        SizedBox(height: u(headerToCardGap)),
        RouteLocationCard(
          u: u,
          semanticsLabel: semanticsLabel,
          location: location,
          onTap: onTap,
        ),
        if (error != null) _ErrorText(u: u, text: error!),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.u,
    required this.title,
    required this.onAction,
  });

  final double Function(double) u;
  final String title;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: u(23),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              title,
              maxLines: 1,
              style: _style(
                u,
                20,
                FontWeight.w600,
                PublishRouteDesignTokens.dark,
                1.15,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: u(-10.5),
            child: Semantics(
              button: true,
              label: 'Добавить, $title',
              child: GestureDetector(
                onTap: onAction,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: u(44),
                  child: Center(
                    child: Text(
                      'Добавить',
                      style: _style(
                        u,
                        16,
                        FontWeight.w500,
                        const Color(0xFF4C4C4C),
                        1,
                      ),
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

class RouteLocationCard extends StatelessWidget {
  const RouteLocationCard({
    required this.u,
    required this.semanticsLabel,
    required this.location,
    required this.onTap,
    super.key,
  });

  final double Function(double) u;
  final String semanticsLabel;
  final RouteLocation? location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(u(14));
    return Semantics(
      button: true,
      label: location == null
          ? '$semanticsLabel, не выбрана'
          : '$semanticsLabel, ${location!.name}, ${location!.subtitle}',
      child: Material(
        key: ValueKey('$semanticsLabel-card'),
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Ink(
            height: u(65),
            decoration: BoxDecoration(
              color: PublishRouteDesignTokens.surface,
              borderRadius: radius,
              border: Border.all(
                color: PublishRouteDesignTokens.border,
                width: u(1),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(left: u(12), right: u(17)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location?.name ?? 'Выберите место',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _style(
                            u,
                            16,
                            FontWeight.w500,
                            PublishRouteDesignTokens.dark,
                            1.05,
                          ),
                        ),
                        SizedBox(height: u(5)),
                        Text(
                          location?.subtitle ?? 'Поиск или выбор на карте',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _style(
                            u,
                            14,
                            FontWeight.w400,
                            PublishRouteDesignTokens.mediumText,
                            1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: PublishRouteDesignTokens.dark,
                    size: u(25),
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

class RouteStopsSection extends StatelessWidget {
  const RouteStopsSection({
    required this.u,
    required this.stops,
    required this.recalculating,
    required this.onAdd,
    required this.onEdit,
    required this.onReorder,
    super.key,
  });

  final double Function(double) u;
  final List<RouteStopDraft> stops;
  final bool recalculating;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final void Function(int, int) onReorder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            _SectionHeader(u: u, title: 'Остановки', onAction: onAdd),
            if (recalculating)
              Positioned(
                right: u(82),
                top: u(4),
                child: SizedBox.square(
                  dimension: u(14),
                  child: CircularProgressIndicator(
                    strokeWidth: u(1.5),
                    color: PublishRouteDesignTokens.secondaryText,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: u(7.5)),
        if (stops.isEmpty)
          SizedBox(
            height: u(52),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Добавьте остановки по пути',
                style: _style(
                  u,
                  14,
                  FontWeight.w400,
                  PublishRouteDesignTokens.secondaryText,
                  1,
                ),
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: stops.length,
            onReorderItem: onReorder,
            proxyDecorator: (child, _, animation) =>
                FadeTransition(opacity: animation, child: child),
            itemBuilder: (context, index) {
              final stop = stops[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(stop.location.id),
                index: index,
                child: RouteStopRow(
                  u: u,
                  index: index + 1,
                  stop: stop,
                  onTap: () => onEdit(index),
                ),
              );
            },
          ),
      ],
    );
  }
}

class RouteStopRow extends StatelessWidget {
  const RouteStopRow({
    required this.u,
    required this.index,
    required this.stop,
    required this.onTap,
    super.key,
  });

  final double Function(double) u;
  final int index;
  final RouteStopDraft stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Остановка $index, ${stop.location.name}, ${_distance(stop)}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: u(52),
          child: Row(
            children: [
              Container(
                width: u(35),
                height: u(35),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: PublishRouteDesignTokens.dark,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: _style(u, 16, FontWeight.w400, Colors.white, 1),
                ),
              ),
              SizedBox(width: u(8)),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.location.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _style(
                        u,
                        15,
                        FontWeight.w500,
                        PublishRouteDesignTokens.dark,
                        1.1,
                      ),
                    ),
                    SizedBox(height: u(3)),
                    Text(
                      _distance(stop),
                      style: _style(
                        u,
                        14,
                        FontWeight.w400,
                        PublishRouteDesignTokens.mediumText,
                        1,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: u(17)),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: PublishRouteDesignTokens.dark,
                  size: u(25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _distance(RouteStopDraft stop) {
    final meters = stop.distanceMeters;
    if (meters == null) {
      return 'Расстояние уточняется';
    }
    return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} км';
  }
}

class RouteMapPreviewCard extends StatelessWidget {
  const RouteMapPreviewCard({
    required this.u,
    required this.golden,
    required this.draft,
    required this.onTap,
    super.key,
  });

  final double Function(double) u;
  final bool golden;
  final RouteDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final routeLocations = [
      if (draft.start != null) draft.start!,
      ...draft.stops.map((stop) => stop.location),
      if (draft.finish != null) draft.finish!,
    ];
    return Semantics(
      button: true,
      label: 'Карта маршрута, ${routeLocations.length} точек',
      child: GestureDetector(
        key: const ValueKey('route-map-preview'),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(u(26)),
          child: SizedBox(
            height: u(320),
            width: double.infinity,
            child: golden
                ? Image.asset(
                    'assets/images/publish_map.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                  )
                : IgnorePointer(
                    child: RouteMapPreview(
                      height: u(320),
                      selectedIndex: null,
                      onPinTap: (_) {},
                      stops: [
                        for (
                          var index = 0;
                          index < routeLocations.length;
                          index++
                        )
                          RouteStop(
                            id: routeLocations[index].id,
                            position: index + 1,
                            placeId: routeLocations[index].id,
                            placeName: routeLocations[index].name,
                            placeSlug: routeLocations[index].id,
                            lat: routeLocations[index].lat,
                            lng: routeLocations[index].lng,
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

class RouteFiltersSection extends StatelessWidget {
  const RouteFiltersSection({
    required this.u,
    required this.filters,
    required this.onToggle,
    required this.onAdd,
    super.key,
  });

  final double Function(double) u;
  final List<String> filters;
  final ValueChanged<String> onToggle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(u: u, title: 'Фильтры маршрута:', onAction: onAdd),
        SizedBox(height: u(13)),
        Semantics(
          label: 'Фильтры маршрута',
          child: Wrap(
            spacing: u(8),
            runSpacing: u(9),
            children: [
              for (final filter in filters)
                RouteFilterChip(
                  u: u,
                  label: filter,
                  onTap: () => onToggle(filter),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class RouteFilterChip extends StatelessWidget {
  const RouteFilterChip({
    required this.u,
    required this.label,
    required this.onTap,
    super.key,
  });

  final double Function(double) u;
  final String label;
  final VoidCallback onTap;

  static const widths = {
    'Природа': 85.0,
    'Пешком': 81.0,
    'С детьми': 88.0,
    'Водопады': 95.0,
    'Романтика': 100.0,
    'Смотровые площадки': 172.0,
    'Леса': 60.0,
  };

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(u(8));
    return Semantics(
      button: true,
      selected: true,
      label: 'Фильтр $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onTap,
          borderRadius: radius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Ink(
            width: u(widths[label] ?? 96),
            height: u(43),
            decoration: BoxDecoration(
              color: PublishRouteDesignTokens.surface,
              borderRadius: radius,
              border: Border.all(
                color: PublishRouteDesignTokens.border,
                width: u(1),
              ),
            ),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style(
                  u,
                  14,
                  FontWeight.w400,
                  PublishRouteDesignTokens.mediumText,
                  1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TravelPaceSelector extends StatelessWidget {
  const TravelPaceSelector({
    required this.u,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final double Function(double) u;
  final TravelPace value;
  final ValueChanged<TravelPace> onChanged;

  @override
  Widget build(BuildContext context) {
    const values = {
      TravelPace.calm: ('Спокойный', 'Больше отдыха\nчем активности'),
      TravelPace.moderate: ('Умеренный', 'Баланс отдыха\nи активности'),
      TravelPace.active: ('Активный', 'Больше актива\nчем отдыха'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FixedText(
          height: u(23),
          text: 'Темп путешествия:',
          style: _style(
            u,
            20,
            FontWeight.w600,
            PublishRouteDesignTokens.dark,
            1.15,
          ),
        ),
        SizedBox(height: u(14)),
        Row(
          children: [
            for (final entry in values.entries) ...[
              if (entry.key != TravelPace.calm) SizedBox(width: u(9)),
              TravelPaceCard(
                u: u,
                title: entry.value.$1,
                subtitle: entry.value.$2,
                selected: value == entry.key,
                onTap: () => onChanged(entry.key),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class TravelPaceCard extends StatelessWidget {
  const TravelPaceCard({
    required this.u,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final double Function(double) u;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(u(8));
    return Semantics(
      button: true,
      selected: selected,
      label: 'Темп $title',
      child: GestureDetector(
        onTap: () {
          unawaited(AppHaptics.selectionClick());
          onTap();
        },
        child: AnimatedContainer(
          key: ValueKey('route-pace-$title'),
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          width: u(127),
          height: u(80),
          decoration: BoxDecoration(
            color: selected
                ? PublishRouteDesignTokens.selectedLightBlue
                : PublishRouteDesignTokens.surface,
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? PublishRouteDesignTokens.primaryBlue
                  : PublishRouteDesignTokens.border,
              width: u(selected ? 1.5 : 1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: _style(
                  u,
                  16,
                  FontWeight.w400,
                  selected
                      ? PublishRouteDesignTokens.primaryBlue
                      : PublishRouteDesignTokens.dark,
                  1,
                ),
              ),
              SizedBox(height: u(7)),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: _style(
                  u,
                  11,
                  FontWeight.w400,
                  selected
                      ? const Color(0xFF4C4C4C)
                      : PublishRouteDesignTokens.secondaryText,
                  1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RouteDifficultySelector extends StatelessWidget {
  const RouteDifficultySelector({
    required this.u,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final double Function(double) u;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const widths = [76.0, 76.0, 76.0, 75.0, 76.0];
    return Semantics(
      label: 'Сложность маршрута, $value из 5',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FixedText(
            height: u(23),
            text: 'Сложность маршрута:',
            style: _style(
              u,
              20,
              FontWeight.w600,
              PublishRouteDesignTokens.dark,
              1.15,
            ),
          ),
          SizedBox(height: u(14)),
          Row(
            children: [
              for (var index = 0; index < 5; index++) ...[
                if (index > 0) SizedBox(width: u(5)),
                _DifficultySegment(
                  u: u,
                  width: widths[index],
                  selected: index < value,
                  onTap: () {
                    unawaited(AppHaptics.selectionClick());
                    onChanged(index + 1);
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DifficultySegment extends StatelessWidget {
  const _DifficultySegment({
    required this.u,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final double Function(double) u;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        width: u(width),
        height: u(44),
        decoration: BoxDecoration(
          color: selected
              ? PublishRouteDesignTokens.primaryBlue
              : PublishRouteDesignTokens.background,
          borderRadius: BorderRadius.circular(u(5)),
          border: Border.all(
            color: selected
                ? PublishRouteDesignTokens.primaryBlue
                : PublishRouteDesignTokens.border,
            width: u(1),
          ),
        ),
        child: Icon(
          Icons.bolt_rounded,
          size: u(21),
          color: selected
              ? Colors.white
              : PublishRouteDesignTokens.disabledIcon,
        ),
      ),
    );
  }
}

class PublishRouteActions extends StatelessWidget {
  const PublishRouteActions({
    required this.u,
    required this.publishing,
    required this.saving,
    required this.onPublish,
    required this.onSave,
    super.key,
  });

  final double Function(double) u;
  final bool publishing;
  final bool saving;
  final VoidCallback onPublish;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RouteActionButton(
          u: u,
          height: 62,
          label: 'Опубликовать маршрут',
          semanticsLabel: 'Опубликовать маршрут',
          loading: publishing,
          background: PublishRouteDesignTokens.dark,
          foreground: Colors.white,
          onTap: publishing ? null : onPublish,
        ),
        SizedBox(height: u(8)),
        _RouteActionButton(
          u: u,
          height: 63,
          label: 'Сохранить черновик',
          semanticsLabel: 'Сохранить черновик',
          loading: saving,
          background: PublishRouteDesignTokens.surface,
          foreground: PublishRouteDesignTokens.dark,
          border: PublishRouteDesignTokens.border,
          onTap: saving ? null : onSave,
        ),
      ],
    );
  }
}

class _RouteActionButton extends StatelessWidget {
  const _RouteActionButton({
    required this.u,
    required this.height,
    required this.label,
    required this.semanticsLabel,
    required this.loading,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.border,
  });

  final double Function(double) u;
  final double height;
  final String label;
  final String semanticsLabel;
  final bool loading;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(u(height / 2));
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticsLabel,
      child: Material(
        key: ValueKey('route-action-$semanticsLabel'),
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Ink(
            width: double.infinity,
            height: u(height),
            decoration: BoxDecoration(
              color: background,
              borderRadius: radius,
              border: border == null
                  ? null
                  : Border.all(color: border!, width: u(1)),
            ),
            child: Center(
              child: loading
                  ? SizedBox.square(
                      dimension: u(20),
                      child: CircularProgressIndicator(
                        strokeWidth: u(2),
                        color: foreground,
                      ),
                    )
                  : Text(
                      label,
                      style: _style(u, 18, FontWeight.w400, foreground, 1),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.u, required this.text});
  final double Function(double) u;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: u(4)),
      child: Text(
        text,
        style: _style(
          u,
          11,
          FontWeight.w400,
          PublishRouteDesignTokens.error,
          1.15,
        ),
      ),
    );
  }
}

class _MediaPickerSheet extends StatelessWidget {
  const _MediaPickerSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _item(
            context,
            Icons.photo_outlined,
            'Выбрать фото',
            RouteMediaSource.galleryImage,
          ),
          _item(
            context,
            Icons.photo_camera_outlined,
            'Снять фото',
            RouteMediaSource.cameraImage,
          ),
          _item(
            context,
            Icons.video_library_outlined,
            'Выбрать видео',
            RouteMediaSource.galleryVideo,
          ),
          _item(
            context,
            Icons.videocam_outlined,
            'Снять видео',
            RouteMediaSource.cameraVideo,
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    RouteMediaSource source,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.of(context).pop(source),
    );
  }
}

class _NoGlowScrollBehavior extends MaterialScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
