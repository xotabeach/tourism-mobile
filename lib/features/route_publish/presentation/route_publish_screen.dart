import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/components/app_brand_bar.dart';
import 'package:tourism_mobile/core/design/components/app_edge_back_gesture.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/domain/content_tags.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/core/media/photo_editor_screen.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/route_publish/application/route_publish_controller.dart';
import 'package:tourism_mobile/features/route_publish/data/route_media_picker.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/domain/route_publish_repository.dart';
import 'package:tourism_mobile/features/route_publish/presentation/publish_route_design_tokens.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_place_picker_sheet.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_preview.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_static_map.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

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

class _RoutePublishScreenState extends ConsumerState<RoutePublishScreen>
    with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
  }

  /// Backgrounding is a moment the app may be killed: write what is pending
  /// and hand it to the sync service now.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_mode != RoutePublishMode.production) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(
        ref.read(routePublishControllerProvider(_mode).notifier).flush(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    // The controller's own dispose also hands edits over; flushing here first
    // gets the send started before the navigation tears the screen down.
    if (_mode == RoutePublishMode.production) {
      unawaited(
        ref.read(routePublishControllerProvider(_mode).notifier).flush(),
      );
    }
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
      if (next.conflict && previous?.conflict != true) {
        unawaited(_askConflict());
      }
      final replaceFor = next.replaceConfirmFor;
      if (replaceFor != null && replaceFor != previous?.replaceConfirmFor) {
        unawaited(_askReplace(replaceFor));
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
                                      SizedBox(height: u(8)),
                                      // Top bar from the design: the screen
                                      // is a shell tab, so «back» leaves to
                                      // Home when there is nothing to pop.
                                      SettingsTopBar(
                                        key: const ValueKey(
                                          'route-publish-top-bar',
                                        ),
                                        arrowBack: true,
                                        onBack: () => context.canPop()
                                            ? context.pop()
                                            : context.goNamed(
                                                AppRouteNames.home,
                                              ),
                                      ),
                                      SizedBox(height: u(20)),
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
                                        preview: state.routePreview,
                                        config: ref.watch(appConfigProvider),
                                        // The golden fixture renders a
                                        // baked image and has no session to
                                        // read a token from.
                                        imageHeaders:
                                            _mode == RoutePublishMode.golden
                                            ? const {}
                                            : _mapImageHeaders(ref),
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
                                        onSave: () => _save(controller, state),
                                      ),
                                      if (_mode ==
                                          RoutePublishMode.production) ...[
                                        SizedBox(height: u(10)),
                                        _DraftStatusBar(
                                          state: state,
                                          onStartNew: () =>
                                              _confirmStartNew(controller),
                                          onOpenDrafts:
                                              controller.openDraftsList,
                                        ),
                                      ],
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
                    draft: state.availableDraft,
                    serverDrafts: _otherDrafts(state, state.availableDraft),
                    busy: state.isOpeningDraft,
                    onContinue: controller.continueDraft,
                    onStartNew: controller.startNewDraft,
                    onOpenServerDraft: controller.openServerDraft,
                  ),
                )
              else if (_mode == RoutePublishMode.production &&
                  state.draftsListOpen &&
                  _otherDrafts(state, state.draft).isNotEmpty)
                Positioned.fill(
                  child: _DraftRecoveryOverlay(
                    serverDrafts: _otherDrafts(state, state.draft),
                    busy: state.isOpeningDraft,
                    // An empty form: the choice is between a saved draft and
                    // a new route. Mid-edit: only a way back to the form.
                    closeLabel: state.draft.hasMeaningfulContent
                        ? 'Закрыть'
                        : 'Начать новый маршрут',
                    onClose: controller.closeDraftsList,
                    onOpenServerDraft: controller.openServerDraft,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return _mode == RoutePublishMode.production
        ? PopScope(
            // System back or a plain pop: nothing blocks it, but the pending
            // edits are handed over on the way out.
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) {
                unawaited(controller.flush());
              }
            },
            child: AppEdgeBackGesture(onBack: _goBack, child: content),
          )
        : content;
  }

  /// A route already through review goes back on moderation when saved.
  Future<void> _save(
    RoutePublishController controller,
    RoutePublishState state,
  ) async {
    if (state.draft.isLiveRoute) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Сохранить изменения?'),
          content: const Text(
            'Маршрут уже опубликован или на проверке. После сохранения он '
            'вернётся на модерацию.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await controller.saveDraft();
  }

  Future<void> _confirmStartNew(RoutePublishController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Начать заново?'),
        content: const Text(
          'Черновик на этом устройстве будет очищен. Если он уже сохранён на '
          'сервере, он останется в списке ваших черновиков.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Начать заново'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.startNewDraft();
    }
  }

  /// Saved drafts other than the one [shown] (already on the form or
  /// offered to continue), which would otherwise be listed twice.
  static List<RouteSummary> _otherDrafts(
    RoutePublishState state,
    RouteDraft? shown,
  ) {
    final id = shown?.serverId;
    return [
      for (final route in state.serverDrafts)
        if (route.id != id) route,
    ];
  }

  Future<void> _askConflict() async {
    final controller = ref.read(routePublishControllerProvider(_mode).notifier);
    final keepMine = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Черновик изменился на другом устройстве'),
        content: const Text(
          'Эта копия основана на более старой версии. Ничего не потеряется: '
          'выберите, какую версию оставить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Взять версию с сервера'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Сохранить мою как новый'),
          ),
        ],
      ),
    );
    if (keepMine == true) {
      await controller.resolveConflictKeepMine();
    } else {
      await controller.resolveConflictTakeServer();
    }
  }

  Future<void> _askReplace(String routeId) async {
    final controller = ref.read(routePublishControllerProvider(_mode).notifier);
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заменить текущий черновик?'),
        content: const Text(
          'Текущие правки не удалось отправить на сервер. Если открыть другой '
          'черновик, они будут потеряны.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Оставить текущий'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Заменить'),
          ),
        ],
      ),
    );
    if (replace == true) {
      await controller.openServerDraft(routeId, confirmedReplace: true);
    }
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
        crop: (paths) => cropPickedPhotos(
          context,
          sourcePaths: paths,
          shape: PhotoCropShape.original,
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

/// One line about where the draft is, plus the two small actions that used to
/// live only in the old recovery dialog. Plain text on purpose: the meaning
/// must not depend on colour, and a screen reader announces every change.
class _DraftStatusBar extends StatelessWidget {
  const _DraftStatusBar({
    required this.state,
    required this.onStartNew,
    required this.onOpenDrafts,
  });

  final RoutePublishState state;
  final VoidCallback onStartNew;
  final VoidCallback onOpenDrafts;

  static String label(RoutePublishState state) => switch (state.saveStatus) {
    DraftSaveStatus.idle => '',
    DraftSaveStatus.savedLocal => 'Сохранено на устройстве',
    // Photos are what makes a send long: say which one is going.
    DraftSaveStatus.syncing when state.uploadsTotal > 0 =>
      'Отправляем фото ${math.min(state.uploadsDone + 1, state.uploadsTotal)}'
          ' из ${state.uploadsTotal}…',
    DraftSaveStatus.syncing => 'Отправляем на сервер…',
    DraftSaveStatus.synced => 'Сохранено · синхронизировано',
    DraftSaveStatus.offline =>
      'Нет соединения. Черновик на устройстве, отправим, когда появится сеть',
    DraftSaveStatus.timedOut =>
      'Сервер не ответил вовремя. Черновик на устройстве, повторим отправку',
    DraftSaveStatus.sendFailed =>
      'Не удалось отправить на сервер. Черновик на устройстве, повторим отправку',
    DraftSaveStatus.localFailed => 'Не удалось сохранить на устройстве',
  };

  @override
  Widget build(BuildContext context) {
    final text = label(state);
    final restored = state.restoredNotice;
    final style = PublishRouteDesignTokens.rubik(
      fontSize: 13,
      weight: FontWeight.w400,
      color: PublishRouteDesignTokens.secondaryText,
      height: 1.25,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          container: true,
          label: text.isEmpty ? null : text,
          child: Text(
            restored && text.isNotEmpty
                ? 'Черновик восстановлен · $text'
                : text,
            key: const ValueKey('route-draft-status'),
            style: style,
          ),
        ),
        if (state.draft.hasMeaningfulContent || state.serverDrafts.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              if (state.draft.hasMeaningfulContent)
                TextButton(
                  key: const ValueKey('route-draft-start-over'),
                  onPressed: onStartNew,
                  child: const Text('Начать заново'),
                ),
              if (state.serverDrafts.isNotEmpty)
                TextButton(
                  key: const ValueKey('route-draft-my-drafts'),
                  onPressed: onOpenDrafts,
                  child: Text('Мои черновики (${state.serverDrafts.length})'),
                ),
            ],
          ),
      ],
    );
  }
}

/// The window over the form that offers saved drafts: the one on this device
/// to continue ([draft]), with the others behind a disclosure; or, without a
/// local one, the list of saved drafts itself.
class _DraftRecoveryOverlay extends StatefulWidget {
  const _DraftRecoveryOverlay({
    required this.serverDrafts,
    required this.busy,
    required this.onOpenServerDraft,
    this.draft,
    this.onContinue,
    this.onStartNew,
    this.onClose,
    this.closeLabel = 'Закрыть',
  });

  final RouteDraft? draft;

  /// Other drafts the user has saved. Hidden behind a disclosure rather than
  /// listed up front: the local draft is what they were last working on, and
  /// that stays the one-tap answer.
  final List<RouteSummary> serverDrafts;
  final bool busy;
  final VoidCallback? onContinue;
  final Future<void> Function()? onStartNew;

  /// Without a local draft: closes the window and leaves the form as it is.
  final VoidCallback? onClose;
  final String closeLabel;
  final Future<void> Function(String routeId) onOpenServerDraft;

  @override
  State<_DraftRecoveryOverlay> createState() => _DraftRecoveryOverlayState();
}

class _DraftRecoveryOverlayState extends State<_DraftRecoveryOverlay> {
  late var _listOpen = widget.draft == null;

  String _updatedLabel(RouteDraft draft) {
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
    final draft = widget.draft;
    final count = widget.serverDrafts.length;
    final heading = draft != null
        ? 'У вас есть черновик'
        : 'У вас есть черновики';
    final title = draft == null
        ? 'Выберите, какой продолжить'
        : draft.title.trim().isEmpty
        ? 'Маршрут без названия'
        : draft.title.trim();
    final detail = draft == null
        ? '${_draftsCount(count)} на сервере'
        : _updatedLabel(draft);
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
                label: draft != null
                    ? 'Найден сохранённый черновик маршрута'
                    : 'Сохранённые черновики маршрутов',
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
                        heading,
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
                        detail,
                        textAlign: TextAlign.center,
                        style: PublishRouteDesignTokens.rubik(
                          fontSize: 13,
                          weight: FontWeight.w400,
                          color: PublishRouteDesignTokens.secondaryText,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (draft == null)
                        _DraftList(
                          drafts: widget.serverDrafts,
                          busy: widget.busy,
                          onOpen: (id) =>
                              unawaited(widget.onOpenServerDraft(id)),
                        )
                      else ...[
                        _DraftChoiceButton(
                          key: const ValueKey('route-draft-continue'),
                          label: 'Продолжить',
                          filled: true,
                          onTap: widget.busy ? null : widget.onContinue,
                        ),
                      ],
                      if (draft != null && widget.serverDrafts.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        _DraftChoiceButton(
                          key: const ValueKey('route-draft-open-list'),
                          label: _listOpen
                              ? 'Скрыть черновики'
                              : 'Открыть черновики'
                                    ' (${widget.serverDrafts.length})',
                          filled: false,
                          onTap: widget.busy
                              ? null
                              : () => setState(() => _listOpen = !_listOpen),
                        ),
                        // Grows the card instead of replacing it, so the
                        // choice above stays put while the list appears.
                        AnimatedSize(
                          duration: AppMotion.normal,
                          curve: AppMotion.standard,
                          alignment: Alignment.topCenter,
                          child: _listOpen
                              ? _DraftList(
                                  drafts: widget.serverDrafts,
                                  busy: widget.busy,
                                  onOpen: (id) =>
                                      unawaited(widget.onOpenServerDraft(id)),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                      const SizedBox(height: 9),
                      if (widget.onStartNew case final startNew?)
                        _DraftChoiceButton(
                          key: const ValueKey('route-draft-start-new'),
                          label: 'Начать заново',
                          filled: false,
                          onTap: widget.busy
                              ? null
                              : () => unawaited(startNew()),
                        )
                      else
                        _DraftChoiceButton(
                          key: const ValueKey('route-draft-close'),
                          label: widget.closeLabel,
                          filled: false,
                          onTap: widget.busy ? null : widget.onClose,
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

String _draftsCount(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'черновик'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? 'черновика'
      : 'черновиков';
  return '$count $word';
}

/// Scrollable, height-capped list of saved drafts.
///
/// Capped because there is no upper bound on how many drafts someone keeps —
/// an unbounded list would push the card past the screen and take the
/// buttons with it.
class _DraftList extends StatelessWidget {
  const _DraftList({
    required this.drafts,
    required this.busy,
    required this.onOpen,
  });

  static const double _maxHeight = 214;

  final List<RouteSummary> drafts;
  final bool busy;
  final void Function(String routeId) onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: PublishRouteDesignTokens.background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: ListView.separated(
            key: const ValueKey('route-draft-list'),
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: drafts.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              indent: 14,
              endIndent: 14,
              color: PublishRouteDesignTokens.border,
            ),
            itemBuilder: (context, index) {
              final draft = drafts[index];
              final title = draft.name.trim().isEmpty
                  ? 'Маршрут без названия'
                  : draft.name.trim();
              final byAssistant = draft.source == 'generated';
              return Semantics(
                button: true,
                label: byAssistant
                    ? 'Открыть черновик: $title, собран ИИ-помощником'
                    : 'Открыть черновик: $title',
                excludeSemantics: true,
                child: InkWell(
                  onTap: busy ? null : () => onOpen(draft.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PublishRouteDesignTokens.rubik(
                                  fontSize: 15,
                                  weight: FontWeight.w500,
                                  color: PublishRouteDesignTokens.dark,
                                  height: 1.2,
                                ),
                              ),
                              if (byAssistant) ...[
                                const SizedBox(height: 6),
                                const _AssistantDraftBadge(),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: PublishRouteDesignTokens.secondaryText,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Marks a draft the AI assistant put together in the chat, so it is not
/// mistaken for one the person wrote («Крым · Природа» looked like a stranger's).
class _AssistantDraftBadge extends StatelessWidget {
  const _AssistantDraftBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('route-draft-assistant-badge'),
      padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
      decoration: BoxDecoration(
        color: PublishRouteDesignTokens.selectedLightBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 13,
            color: PublishRouteDesignTokens.primaryBlue,
          ),
          const SizedBox(width: 4),
          Text(
            'ИИ-помощник',
            style: PublishRouteDesignTokens.rubik(
              fontSize: 12,
              weight: FontWeight.w500,
              color: PublishRouteDesignTokens.primaryBlue,
              height: 1.2,
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
  final VoidCallback? onTap;

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

class _RouteMediaPreview extends ConsumerWidget {
  const _RouteMediaPreview({required this.item});

  final RouteMediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    if (item.isAsset) {
      return Image.asset(item.path, fit: BoxFit.cover);
    }
    // A photo the draft already stores on the server has a public path, not
    // a file path. Opening it as a file left the tile showing a broken-image
    // icon while the very same photo rendered on the route card in the
    // profile (reported 2026-09-08).
    if (item.isRemote) {
      return AppImages.coverImage(
        config: ref.watch(appConfigProvider),
        coverImageUrl: item.path,
        fallbackSeed: item.id,
      );
    }
    return Image.file(
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

/// Bearer token for the private preview raster, when there is one.
Map<String, String> _mapImageHeaders(WidgetRef ref) {
  final token = ref.watch(sessionProvider).accessToken;
  return token == null || token.isEmpty
      ? const {}
      : {'Authorization': 'Bearer $token'};
}

class RouteMapPreviewCard extends StatelessWidget {
  const RouteMapPreviewCard({
    required this.u,
    required this.golden,
    required this.draft,
    required this.onTap,
    this.preview,
    this.config,
    this.imageHeaders = const {},
    super.key,
  });

  final double Function(double) u;
  final bool golden;
  final RouteDraft draft;
  final VoidCallback onTap;

  /// Road geometry for the points placed so far. Until it arrives (or when
  /// routing is unavailable) the card keeps the stylised diagram — the
  /// author still sees their points, just not the roads.
  final RouteDraftPreview? preview;
  final AppConfig? config;

  /// The preview raster is private to its author, so it authenticates —
  /// without the token the request 401s and the card silently falls back to
  /// the stylised diagram (reported 2026-09-08 as "карта не отображается").
  final Map<String, String> imageHeaders;

  @override
  Widget build(BuildContext context) {
    final routeLocations = [
      if (draft.start != null) draft.start!,
      ...draft.stops.map((stop) => stop.location),
      if (draft.finish != null) draft.finish!,
    ];
    final stops = [
      for (var index = 0; index < routeLocations.length; index++)
        RouteStop(
          id: routeLocations[index].id,
          position: index + 1,
          placeId: routeLocations[index].id,
          placeSlug: routeLocations[index].id,
          placeName: routeLocations[index].name,
          lat: routeLocations[index].lat,
          lng: routeLocations[index].lng,
        ),
    ];
    final routePreview = preview;
    final previewConfig = config;
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
                : routePreview != null && previewConfig != null
                ? IgnorePointer(
                    child: RouteStaticMap(
                      key: const ValueKey('route-map-preview-static'),
                      staticMapUrl: routePreview.staticMapPath,
                      stops: stops,
                      geometry: routePreview.geometry,
                      config: previewConfig,
                      imageHeaders: imageHeaders,
                      height: u(320),
                      interactive: false,
                      footerLabel: routePointsLabel(routeLocations.length),
                    ),
                  )
                : IgnorePointer(
                    child: RouteMapPreview(
                      height: u(320),
                      selectedIndex: null,
                      onPinTap: (_) {},
                      stops: stops,
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
      label:
          'Сложность маршрута, $value из 5${value == 5 ? ', очень сложный' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FixedText(
            height: u(23),
            text: value == 5
                ? 'Сложность: очень сложный'
                : 'Сложность маршрута:',
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
          busyLabel: 'Публикуем…',
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
          busyLabel: 'Сохраняем…',
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
    required this.busyLabel,
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
  final String busyLabel;
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
              // While busy the button keeps words next to the spinner: a
              // lone spinner on the white button read as an empty button
              // with a dot in it.
              child: loading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: u(18),
                          child: CircularProgressIndicator(
                            strokeWidth: u(2),
                            color: foreground,
                          ),
                        ),
                        SizedBox(width: u(10)),
                        Text(
                          busyLabel,
                          style: _style(u, 18, FontWeight.w400, foreground, 1),
                        ),
                      ],
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
