
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/storage/secure_storage_provider.dart';
import 'package:tourism_mobile/features/route_publish/data/api_route_publication_repository.dart';
import 'package:tourism_mobile/features/route_publish/data/route_media_picker.dart';
import 'package:tourism_mobile/features/route_publish/data/secure_route_draft_repository.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/domain/route_publish_repository.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/domain/routes_repository.dart';

enum RoutePublishMode { production, golden }

class RoutePublishState {
  const RoutePublishState({
    required this.draft,
    this.availableDraft,
    this.serverDrafts = const [],
    this.isOpeningDraft = false,
    this.routePreview,
    this.isPreviewLoading = false,
    this.isHydrating = false,
    this.isPickingMedia = false,
    this.isSaving = false,
    this.isPublishing = false,
    this.isRecalculating = false,
    this.titleError,
    this.descriptionError,
    this.mediaError,
    this.startError,
    this.finishError,
    this.routeError,
    this.message,
    this.messageSerial = 0,
  });

  final RouteDraft draft;
  final RouteDraft? availableDraft;

  /// Drafts already saved on the server. The local `availableDraft` is only
  /// ever the one unfinished edit on this device, so without these the
  /// prompt could not offer the other drafts the user actually has.
  final List<RouteSummary> serverDrafts;
  final bool isOpeningDraft;

  /// Road geometry for the points placed so far, recomputed in the
  /// background as they change. Null until the first answer comes back (or
  /// when routing is unavailable) — the form then draws its own diagram.
  final RouteDraftPreview? routePreview;
  final bool isPreviewLoading;
  final bool isHydrating;
  final bool isPickingMedia;
  final bool isSaving;
  final bool isPublishing;
  final bool isRecalculating;
  final String? titleError;
  final String? descriptionError;
  final String? mediaError;
  final String? startError;
  final String? finishError;
  final String? routeError;
  final String? message;
  final int messageSerial;

  RoutePublishState copyWith({
    RouteDraft? draft,
    RouteDraft? availableDraft,
    List<RouteSummary>? serverDrafts,
    bool? isOpeningDraft,
    RouteDraftPreview? routePreview,
    bool? isPreviewLoading,
    bool clearRoutePreview = false,
    bool clearAvailableDraft = false,
    bool? isHydrating,
    bool? isPickingMedia,
    bool? isSaving,
    bool? isPublishing,
    bool? isRecalculating,
    String? titleError,
    bool clearTitleError = false,
    String? descriptionError,
    bool clearDescriptionError = false,
    String? mediaError,
    bool clearMediaError = false,
    String? startError,
    bool clearStartError = false,
    String? finishError,
    bool clearFinishError = false,
    String? routeError,
    bool clearRouteError = false,
    String? message,
    bool clearMessage = false,
    int? messageSerial,
  }) {
    return RoutePublishState(
      draft: draft ?? this.draft,
      serverDrafts: serverDrafts ?? this.serverDrafts,
      isOpeningDraft: isOpeningDraft ?? this.isOpeningDraft,
      routePreview: clearRoutePreview
          ? null
          : (routePreview ?? this.routePreview),
      isPreviewLoading: isPreviewLoading ?? this.isPreviewLoading,
      availableDraft: clearAvailableDraft
          ? null
          : availableDraft ?? this.availableDraft,
      isHydrating: isHydrating ?? this.isHydrating,
      isPickingMedia: isPickingMedia ?? this.isPickingMedia,
      isSaving: isSaving ?? this.isSaving,
      isPublishing: isPublishing ?? this.isPublishing,
      isRecalculating: isRecalculating ?? this.isRecalculating,
      titleError: clearTitleError ? null : titleError ?? this.titleError,
      descriptionError: clearDescriptionError
          ? null
          : descriptionError ?? this.descriptionError,
      mediaError: clearMediaError ? null : mediaError ?? this.mediaError,
      startError: clearStartError ? null : startError ?? this.startError,
      finishError: clearFinishError ? null : finishError ?? this.finishError,
      routeError: clearRouteError ? null : routeError ?? this.routeError,
      message: clearMessage ? null : message ?? this.message,
      messageSerial: messageSerial ?? this.messageSerial,
    );
  }
}

final routeMediaPickerProvider = Provider<RouteMediaPicker>((ref) {
  return ImagePickerRouteMediaPicker(ImagePicker());
});

final routeDraftRepositoryProvider = Provider<RouteDraftRepository>((ref) {
  return SecureRouteDraftRepository(ref.watch(secureStorageProvider));
});

final routePublicationRepositoryProvider = Provider<RoutePublicationRepository>(
  (ref) {
    if (ref.watch(appConfigProvider).useMockData) {
      return const InMemoryRoutePublicationRepository();
    }
    return ApiRoutePublicationRepository(ref.watch(dioProvider));
  },
);

final routePublishControllerProvider = StateNotifierProvider.autoDispose
    .family<RoutePublishController, RoutePublishState, RoutePublishMode>((
      ref,
      mode,
    ) {
      return RoutePublishController(
        mode: mode,
        drafts: ref.watch(routeDraftRepositoryProvider),
        mediaPicker: ref.watch(routeMediaPickerProvider),
        publication: ref.watch(routePublicationRepositoryProvider),
        routes: ref.watch(routesRepositoryProvider),
      );
    });

class RoutePublishController extends StateNotifier<RoutePublishState> {
  RoutePublishController({
    required RoutePublishMode mode,
    required this._drafts,
    required this._mediaPicker,
    required this._publication,
    required this._routes,
  }) : _mode = mode,
       super(
         RoutePublishState(
           draft: mode == RoutePublishMode.golden
               ? RouteDraft.golden()
               : const RouteDraft(),
           isHydrating: mode == RoutePublishMode.production,
         ),
       ) {
    if (mode == RoutePublishMode.production) {
      unawaited(_hydrate());
    }
  }

  static const maxMedia = 10;

  final RoutePublishMode _mode;
  final RouteDraftRepository _drafts;
  final RouteMediaPicker _mediaPicker;
  final RoutePublicationRepository _publication;
  final RoutesRepository _routes;

  Timer? _previewDebounce;
  int _previewGeneration = 0;

  Future<void> _hydrate() async {
    try {
      final draft = await _drafts.load();
      if (!mounted) {
        return;
      }
      if (draft == null || !draft.hasMeaningfulContent) {
        state = state.copyWith(isHydrating: false);
        return;
      }
      if (draft.publicationStatus != RoutePublicationStatus.draft &&
          draft.publicationStatus != RoutePublicationStatus.rejected) {
        await _drafts.delete();
        if (mounted) {
          state = state.copyWith(isHydrating: false, clearAvailableDraft: true);
        }
        return;
      }
      state = state.copyWith(availableDraft: draft, isHydrating: false);
      unawaited(_loadServerDrafts());
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          isHydrating: false,
          message: 'Не удалось восстановить черновик',
          messageSerial: state.messageSerial + 1,
        );
      }
    }
  }

  /// Every route of the user's still sitting in `draft`. Best-effort: the
  /// prompt works with just the local draft when this fails.
  Future<void> _loadServerDrafts() async {
    try {
      final page = await _routes.listMyRoutes();
      if (!mounted) {
        return;
      }
      final drafts = page.items
          .where((route) => route.publicationStatus == 'draft')
          .toList(growable: false);
      state = state.copyWith(serverDrafts: drafts);
    } on Object {
      // Offline or a failed call: the local draft is still offered.
    }
  }

  /// Opens one of the server drafts in the editor, replacing whatever the
  /// prompt was offering.
  Future<void> openServerDraft(String routeId) async {
    if (state.isOpeningDraft) {
      return;
    }
    state = state.copyWith(isOpeningDraft: true);
    try {
      final draft = await _publication.loadForEdit(routeId);
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        draft: draft,
        isOpeningDraft: false,
        clearAvailableDraft: true,
      );
      await _drafts.save(draft);
    } on Object {
      if (mounted) {
        state = state.copyWith(isOpeningDraft: false);
        _message('Не удалось открыть черновик');
      }
    }
  }

  void continueDraft() {
    final draft = state.availableDraft;
    if (draft == null) {
      return;
    }
    state = state.copyWith(draft: draft, clearAvailableDraft: true);
  }

  Future<void> startNewDraft() async {
    final saved = state.availableDraft;
    state = state.copyWith(
      draft: const RouteDraft(),
      clearAvailableDraft: true,
    );
    try {
      await _drafts.delete();
    } catch (_) {
      _message(
        'Новый маршрут начат, но локальный черновик удалить не удалось.',
      );
    }
    final serverId = saved?.serverId;
    if (serverId != null && serverId.isNotEmpty) {
      try {
        await _publication.discardDraft(serverId);
      } on AppFailure {
        _message('Новый маршрут начат. Серверный черновик удалить не удалось.');
      }
    }
  }

  void setTitle(String value) {
    state = state.copyWith(
      draft: state.draft.copyWith(title: value),
      clearTitleError: true,
    );
  }

  void setDescription(String value) {
    state = state.copyWith(
      draft: state.draft.copyWith(description: value),
      clearDescriptionError: true,
    );
  }

  /// [crop] позволяет экрану вклиниться между выбором и добавлением, чтобы
  /// автор сам выбрал кадр. Контроллер не знает про UI, поэтому редактор
  /// приходит колбэком; для видео он не вызывается — кадрировать там нечего.
  Future<void> addMedia(
    RouteMediaSource source, {
    Future<String?> Function(String path)? crop,
  }) async {
    if (state.isPickingMedia) {
      return;
    }
    if (state.draft.media.length >= maxMedia) {
      _message('Можно добавить не больше $maxMedia файлов');
      return;
    }
    state = state.copyWith(isPickingMedia: true, clearMediaError: true);
    try {
      final picked = await _mediaPicker.pick(source);
      if (picked == null || !mounted) {
        return;
      }
      var item = picked;
      if (crop != null && picked.kind == RouteMediaKind.image) {
        final cropped = await crop(picked.path);
        if (cropped == null || !mounted) {
          return;
        }
        item = picked.copyWith(path: cropped);
      }
      if (state.draft.media.any((existing) => existing.path == item.path)) {
        _message('Этот файл уже добавлен');
        return;
      }
      state = state.copyWith(
        draft: state.draft.copyWith(media: [...state.draft.media, item]),
        clearMediaError: true,
      );
    } on FormatException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Не удалось добавить файл. Проверьте разрешения и повторите.');
    } finally {
      if (mounted) {
        state = state.copyWith(isPickingMedia: false);
      }
    }
  }

  void removeMedia(String id) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        media: state.draft.media.where((item) => item.id != id).toList(),
      ),
    );
  }

  void reorderMedia(int oldIndex, int newIndex) {
    final items = [...state.draft.media];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = state.copyWith(draft: state.draft.copyWith(media: items));
  }

  void setStart(RouteLocation location) {
    if (state.draft.finish?.id == location.id) {
      state = state.copyWith(startError: 'Старт и финиш должны отличаться');
      return;
    }
    state = state.copyWith(
      draft: state.draft.copyWith(start: location),
      clearStartError: true,
      clearRouteError: true,
    );
    _recalculateDistances();
  }

  void setFinish(RouteLocation location) {
    if (state.draft.start?.id == location.id) {
      state = state.copyWith(finishError: 'Старт и финиш должны отличаться');
      return;
    }
    state = state.copyWith(
      draft: state.draft.copyWith(finish: location),
      clearFinishError: true,
      clearRouteError: true,
    );
    _recalculateDistances();
  }

  void addStop(RouteLocation location) {
    if (_containsLocation(location.id)) {
      _message('Эта точка уже есть в маршруте');
      return;
    }
    state = state.copyWith(
      draft: state.draft.copyWith(
        stops: [
          ...state.draft.stops,
          RouteStopDraft(location: location),
        ],
      ),
      clearRouteError: true,
    );
    _recalculateDistances();
  }

  void replaceStop(int index, RouteLocation location) {
    if (_containsLocation(location.id, ignoringStop: index)) {
      _message('Эта точка уже есть в маршруте');
      return;
    }
    final stops = [...state.draft.stops];
    stops[index] = RouteStopDraft(location: location);
    state = state.copyWith(draft: state.draft.copyWith(stops: stops));
    _recalculateDistances();
  }

  void removeStop(int index) {
    final stops = [...state.draft.stops]..removeAt(index);
    state = state.copyWith(draft: state.draft.copyWith(stops: stops));
    _recalculateDistances();
  }

  void reorderStop(int oldIndex, int newIndex) {
    final stops = [...state.draft.stops];
    final item = stops.removeAt(oldIndex);
    stops.insert(newIndex, item);
    state = state.copyWith(draft: state.draft.copyWith(stops: stops));
    _recalculateDistances();
  }

  bool _containsLocation(String id, {int? ignoringStop}) {
    if (state.draft.start?.id == id || state.draft.finish?.id == id) {
      return true;
    }
    for (var index = 0; index < state.draft.stops.length; index++) {
      if (index != ignoringStop && state.draft.stops[index].location.id == id) {
        return true;
      }
    }
    return false;
  }

  void toggleFilter(String filter) {
    final filters = [...state.draft.filters];
    if (filters.contains(filter)) {
      filters.remove(filter);
    } else {
      filters.add(filter);
    }
    state = state.copyWith(draft: state.draft.copyWith(filters: filters));
  }

  void setPace(TravelPace pace) {
    state = state.copyWith(draft: state.draft.copyWith(pace: pace));
  }

  void setDifficulty(int value) {
    state = state.copyWith(
      draft: state.draft.copyWith(difficulty: value.clamp(1, 5)),
    );
  }

  Future<void> saveDraft() async {
    if (state.isSaving) {
      return;
    }
    if (_mode == RoutePublishMode.golden) {
      _message('Черновик сохранён');
      return;
    }
    state = state.copyWith(isSaving: true);
    try {
      var draft = state.draft.copyWith(
        updatedAt: DateTime.now().toUtc(),
        publicationStatus: RoutePublicationStatus.draft,
      );
      await _drafts.save(draft);
      final canSync =
          draft.title.trim().isNotEmpty &&
          draft.start != null &&
          draft.finish != null;
      if (canSync) {
        try {
          final receipt = await _publication.saveDraft(draft);
          draft = draft.copyWith(
            serverId: receipt.id,
            publicationStatus: receipt.status,
            updatedAt: receipt.updatedAt,
          );
          await _drafts.save(draft);
        } on AppFailure {
          if (mounted) {
            state = state.copyWith(draft: draft);
            _message('Черновик сохранён на устройстве');
          }
          return;
        }
      }
      if (mounted) {
        state = state.copyWith(draft: draft);
        _message('Черновик сохранён');
      }
    } catch (_) {
      _message('Не удалось сохранить черновик. Попробуйте ещё раз.');
    } finally {
      if (mounted) {
        state = state.copyWith(isSaving: false);
      }
    }
  }

  Future<String?> publish() async {
    if (state.isPublishing || !_validate()) {
      return null;
    }
    state = state.copyWith(isPublishing: true);
    try {
      final preparedReceipt = await _publication.saveDraft(state.draft);
      var prepared = state.draft.copyWith(
        serverId: preparedReceipt.id,
        publicationStatus: preparedReceipt.status,
        updatedAt: preparedReceipt.updatedAt,
      );
      await _drafts.save(prepared);
      if (mounted) {
        state = state.copyWith(draft: prepared);
      }
      final submittedReceipt = await _publication.submit(prepared);
      prepared = prepared.copyWith(
        serverId: submittedReceipt.id,
        publicationStatus: submittedReceipt.status,
        updatedAt: submittedReceipt.updatedAt,
      );
      await _drafts.delete();
      if (mounted) {
        state = state.copyWith(draft: prepared, clearAvailableDraft: true);
        _message('Маршрут отправлен на модерацию');
      }
      return submittedReceipt.id;
    } on AppFailure catch (error) {
      await saveDraft();
      _message(error.message);
      return null;
    } catch (_) {
      await saveDraft();
      _message('Не удалось опубликовать маршрут. Черновик сохранён.');
      return null;
    } finally {
      if (mounted) {
        state = state.copyWith(isPublishing: false);
      }
    }
  }

  bool _validate() {
    final draft = state.draft;
    final titleError = draft.title.trim().isEmpty
        ? 'Введите название маршрута'
        : null;
    final mediaError = draft.media.isEmpty ? 'Добавьте фото или видео' : null;
    final startError = draft.start == null ? 'Выберите стартовую точку' : null;
    final finishError = draft.finish == null ? 'Выберите финишную точку' : null;
    final routeError =
        draft.start != null && draft.start?.id == draft.finish?.id
        ? 'Старт и финиш должны отличаться'
        : null;
    state = state.copyWith(
      titleError: titleError,
      clearTitleError: titleError == null,
      mediaError: mediaError,
      clearMediaError: mediaError == null,
      startError: startError,
      clearStartError: startError == null,
      finishError: finishError,
      clearFinishError: finishError == null,
      routeError: routeError,
      clearRouteError: routeError == null,
    );
    return titleError == null &&
        mediaError == null &&
        startError == null &&
        finishError == null &&
        routeError == null;
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    super.dispose();
  }

  /// Ordered place ids currently on the form: start, stops, finish.
  List<String> _routePlaceIds() {
    final draft = state.draft;
    return [
      if (draft.start != null) draft.start!.id,
      for (final stop in draft.stops) stop.location.id,
      if (draft.finish != null) draft.finish!.id,
    ];
  }

  /// Asks the server for the road between the placed points.
  ///
  /// Debounced and generation-checked: placing a start and a finish fires
  /// twice in a row, and reordering stops fires per drag, but only the last
  /// answer may land. Failures leave the previous preview alone rather than
  /// blanking the map the author is looking at.
  void _refreshRoutePreview() {
    _previewDebounce?.cancel();
    final placeIds = _routePlaceIds();
    if (placeIds.length < 2) {
      state = state.copyWith(isPreviewLoading: false, clearRoutePreview: true);
      return;
    }
    final generation = ++_previewGeneration;
    state = state.copyWith(isPreviewLoading: true);
    _previewDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final preview = await _publication.previewRoute(placeIds: placeIds);
        if (!mounted || generation != _previewGeneration) {
          return;
        }
        state = state.copyWith(
          routePreview: preview.geometry == null ? null : preview,
          clearRoutePreview: preview.geometry == null,
          isPreviewLoading: false,
        );
      } on Object {
        // Offline, or routing unavailable: the diagram is still drawn.
        if (mounted && generation == _previewGeneration) {
          state = state.copyWith(isPreviewLoading: false);
        }
      }
    });
  }

  void _recalculateDistances() {
    // Before the early return below: start and finish alone are already a
    // route worth drawing, which is exactly when the author first looks at
    // the map.
    _refreshRoutePreview();
    final start = state.draft.start;
    if (start == null || state.draft.stops.isEmpty) {
      return;
    }
    state = state.copyWith(isRecalculating: true);
    var previous = start;
    var cumulative = 0.0;
    final stops = <RouteStopDraft>[];
    for (final stop in state.draft.stops) {
      cumulative += _haversineMeters(previous, stop.location);
      stops.add(stop.copyWith(distanceMeters: cumulative.round()));
      previous = stop.location;
    }
    state = state.copyWith(
      draft: state.draft.copyWith(stops: stops),
      isRecalculating: false,
    );
  }

  static double _haversineMeters(RouteLocation a, RouteLocation b) {
    const earthRadius = 6371000.0;
    final lat1 = a.lat * math.pi / 180;
    final lat2 = b.lat * math.pi / 180;
    final dLat = (b.lat - a.lat) * math.pi / 180;
    final dLng = (b.lng - a.lng) * math.pi / 180;
    final value =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value));
  }

  void _message(String value) {
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      message: value,
      messageSerial: state.messageSerial + 1,
    );
  }
}
