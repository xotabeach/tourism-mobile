import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tourism_mobile/core/domain/content_tags.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/client_event_id.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/route_publish/application/route_draft_providers.dart';
import 'package:tourism_mobile/features/route_publish/application/route_draft_sync.dart';
import 'package:tourism_mobile/features/route_publish/data/route_draft_media_store.dart';
import 'package:tourism_mobile/features/route_publish/data/route_media_picker.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/domain/route_publish_repository.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/domain/routes_repository.dart';

export 'package:tourism_mobile/features/route_publish/application/route_draft_providers.dart';

enum RoutePublishMode { production, golden }

/// What the status line under the buttons says about the draft.
enum DraftSaveStatus {
  /// Nothing worth saving yet.
  idle,

  /// On the device, not (yet) on the server.
  savedLocal,

  /// Being sent to the server.
  syncing,

  /// Saved on the device and on the server.
  synced,

  /// On the device; the phone has no connection.
  offline,

  /// On the device; the server did not answer in time. Sent again shortly.
  timedOut,

  /// On the device; the server refused or failed. Sent again shortly.
  sendFailed,

  /// The device write itself failed.
  localFailed,
}

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
    this.saveStatus = DraftSaveStatus.idle,
    this.restoredNotice = false,
    this.conflict = false,
    this.replaceConfirmFor,
    this.uploadsDone = 0,
    this.uploadsTotal = 0,
    this.draftsListOpen = false,
  });

  final DraftSaveStatus saveStatus;

  /// Photos sent so far out of those the running send has to upload; both 0
  /// when it has none.
  final int uploadsDone;
  final int uploadsTotal;

  /// The window listing the saved drafts is up (without a local draft to
  /// continue, which [availableDraft] brings up on its own).
  final bool draftsListOpen;

  /// The draft was picked up from a previous session: shown once as a note.
  final bool restoredNotice;

  /// The server copy changed on another device after this one was based on it.
  final bool conflict;

  /// Opening this server draft would replace edits that could not be sent.
  final String? replaceConfirmFor;

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
    DraftSaveStatus? saveStatus,
    bool? restoredNotice,
    bool? conflict,
    String? replaceConfirmFor,
    bool clearReplaceConfirm = false,
    int? uploadsDone,
    int? uploadsTotal,
    bool? draftsListOpen,
  }) {
    return RoutePublishState(
      uploadsDone: uploadsDone ?? this.uploadsDone,
      uploadsTotal: uploadsTotal ?? this.uploadsTotal,
      draftsListOpen: draftsListOpen ?? this.draftsListOpen,
      saveStatus: saveStatus ?? this.saveStatus,
      restoredNotice: restoredNotice ?? this.restoredNotice,
      conflict: conflict ?? this.conflict,
      replaceConfirmFor: clearReplaceConfirm
          ? null
          : replaceConfirmFor ?? this.replaceConfirmFor,
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

/// Set while the form is opened to edit an existing route (from its card), so
/// a live route's local copy is resumed there and nowhere else.
final routePublishEditingExistingProvider = StateProvider<bool>((ref) => false);

final routePublishControllerProvider = StateNotifierProvider.autoDispose
    .family<RoutePublishController, RoutePublishState, RoutePublishMode>((
      ref,
      mode,
    ) {
      return RoutePublishController(
        mode: mode,
        drafts: ref.watch(routeDraftRepositoryProvider),
        mediaPicker: ref.watch(routeMediaPickerProvider),
        mediaStore: ref.watch(routeDraftMediaStoreProvider),
        publication: ref.watch(routePublicationRepositoryProvider),
        routes: ref.watch(routesRepositoryProvider),
        sync: ref.watch(routeDraftSyncServiceProvider),
        // The golden fixture has no account (and must not start a session).
        userId: mode == RoutePublishMode.production
            ? ref.watch(sessionProvider.select((session) => session.userId))
            : null,
        editingExisting: ref.read(routePublishEditingExistingProvider),
      );
    });

class RoutePublishController extends StateNotifier<RoutePublishState> {
  RoutePublishController({
    required RoutePublishMode mode,
    required this._drafts,
    required this._mediaPicker,
    required this._mediaStore,
    required this._publication,
    required this._routes,
    required this._sync,
    this._userId,
    this._editingExisting = false,
    this._autosaveDelay = const Duration(seconds: 2),
    this._sendRetryDelay = const Duration(seconds: 15),
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
      _syncSubscription = _sync.events.listen(_onSyncEvent);
      unawaited(_hydrate());
    }
  }

  static const maxMedia = 10;

  final RoutePublishMode _mode;
  final RouteDraftRepository _drafts;
  final RouteMediaPicker _mediaPicker;
  final RouteDraftMediaStore _mediaStore;
  final RoutePublicationRepository _publication;
  final RoutesRepository _routes;
  final RouteDraftSyncService _sync;
  final String? _userId;
  final bool _editingExisting;
  final Duration _autosaveDelay;

  /// The first pause before a failed send is tried again; later ones double.
  final Duration _sendRetryDelay;

  StreamSubscription<RouteDraftSyncEvent>? _syncSubscription;
  Timer? _autosave;
  Timer? _sendRetry;
  int _sendRetries = 0;

  /// The saved drafts were offered on this visit already.
  bool _draftsPromptShown = false;
  Timer? _localRetry;
  Future<void>? _persistFuture;

  /// Edits not yet written to the device.
  bool _dirty = false;

  /// Another edit landed while a write was running.
  bool _dirtyAgain = false;
  int _localFailures = 0;
  bool _localFailing = false;
  bool _syncing = false;
  RouteDraftSyncOutcome? _lastOutcome;

  // Programmatic replacements of the draft (loading, adopting a send's
  // result) are not edits and must not start an autosave.
  int _quietDepth = 0;

  Timer? _previewDebounce;
  int _previewGeneration = 0;

  /// An edit is any change of the form content while the screen is live.
  /// Hooking the setter covers every mutator (title, places, photos, filters)
  /// without each one having to remember to save.
  @override
  set state(RoutePublishState value) {
    final previous = super.state;
    // Typing while the stored draft is still being read counts too: the
    // Keychain read can take a moment, and those edits used to be dropped.
    if (_mode == RoutePublishMode.production &&
        _quietDepth == 0 &&
        !previous.draft.sameContentAs(value.draft)) {
      super.state = value.copyWith(draft: value.draft.copyWith(unsynced: true));
      _onEdited();
      return;
    }
    super.state = value;
  }

  void _quiet(void Function() change) {
    _quietDepth++;
    try {
      change();
    } finally {
      _quietDepth--;
    }
  }

  void _onEdited() {
    _dirty = true;
    if (_persistFuture != null) {
      _dirtyAgain = true;
    }
    if (state.isHydrating) {
      // Nothing is written before the stored draft has been read: the write
      // would replace it unseen. [_hydrate] schedules the save afterwards.
      return;
    }
    _autosave?.cancel();
    _autosave = Timer(_autosaveDelay, () => unawaited(_persistLocal()));
    _refreshStatus();
  }

  RouteDraft _stamped(RouteDraft draft) {
    return draft.copyWith(
      ownerUserId: draft.ownerUserId ?? _userId,
      clientDraftId: draft.clientDraftId ?? newClientEventId(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Writes the draft to the device. Saves never overlap: one requested while
  /// another runs is remembered and repeated, not dropped.
  Future<void> _persistLocal() {
    final running = _persistFuture;
    if (running != null) {
      _dirtyAgain = true;
      return running;
    }
    final future = _persistLoop().whenComplete(() => _persistFuture = null);
    _persistFuture = future;
    return future;
  }

  Future<void> _persistLoop() async {
    do {
      _dirtyAgain = false;
      if (!mounted) {
        return;
      }
      final stamped = _stamped(state.draft);
      if (!stamped.hasMeaningfulContent) {
        _dirty = false;
        return;
      }
      try {
        await _drafts.save(stamped);
        _localFailures = 0;
        _localFailing = false;
        _dirty = _dirtyAgain;
        if (mounted) {
          _quiet(() {
            state = state.copyWith(
              draft: state.draft.copyWith(
                ownerUserId: stamped.ownerUserId,
                clientDraftId: stamped.clientDraftId,
                updatedAt: stamped.updatedAt,
              ),
            );
          });
        }
      } on Object {
        // A failed write must never read as "saved": say so, and try again
        // with growing pauses instead of spinning.
        _dirty = true;
        _localFailing = true;
        _localFailures++;
        _scheduleLocalRetry();
        _refreshStatus();
        return;
      }
    } while (_dirtyAgain && mounted);
    _refreshStatus();
  }

  void _scheduleLocalRetry() {
    const pauses = [2, 5, 15];
    final seconds = pauses[math.min(_localFailures - 1, pauses.length - 1)];
    _localRetry?.cancel();
    _localRetry = Timer(
      Duration(seconds: seconds),
      () => unawaited(_persistLocal()),
    );
  }

  void _refreshStatus() {
    if (!mounted) {
      return;
    }
    final draft = state.draft;
    final status = !draft.hasMeaningfulContent
        ? DraftSaveStatus.idle
        : _localFailing
        ? DraftSaveStatus.localFailed
        : _syncing
        ? DraftSaveStatus.syncing
        : draft.unsynced
        ? switch (_lastOutcome) {
            RouteDraftSyncOutcome.offline => DraftSaveStatus.offline,
            RouteDraftSyncOutcome.timedOut => DraftSaveStatus.timedOut,
            RouteDraftSyncOutcome.failed => DraftSaveStatus.sendFailed,
            _ => DraftSaveStatus.savedLocal,
          }
        : draft.serverId != null
        ? DraftSaveStatus.synced
        : DraftSaveStatus.savedLocal;
    if (status != state.saveStatus) {
      _quiet(() => state = state.copyWith(saveStatus: status));
    }
  }

  /// Leaving the screen or the app: write what is pending, then let the sync
  /// service send it. The service outlives this controller, so the send
  /// continues after the screen is gone.
  Future<void> flush() async {
    if (_mode != RoutePublishMode.production || state.isHydrating) {
      return;
    }
    _autosave?.cancel();
    _localRetry?.cancel();
    if (_dirty || _persistFuture != null) {
      await _persistLocal();
    }
    unawaited(_sendInBackground());
  }

  Future<void> _sendInBackground() async {
    final userId = _userId;
    if (userId == null || !state.draft.hasMeaningfulContent) {
      return;
    }
    await _send(userId, explicit: false);
  }

  Future<RouteDraftSyncOutcome> _send(
    String userId, {
    required bool explicit,
  }) async {
    _sendRetry?.cancel();
    _syncing = true;
    final uploads = state.draft.media
        .where((item) => !item.isAsset && !item.isOnServer)
        .length;
    _quiet(() {
      state = state.copyWith(uploadsDone: 0, uploadsTotal: uploads);
    });
    _refreshStatus();
    final outcome = await _sync.sync(userId, state.draft, explicit: explicit);
    _syncing = false;
    _lastOutcome = outcome;
    if (mounted) {
      _quiet(() {
        state = state.copyWith(uploadsDone: 0, uploadsTotal: 0);
      });
      _reportOutcome(outcome, explicit: explicit);
      _refreshStatus();
      _scheduleSendRetry(outcome);
    }
    return outcome;
  }

  /// A send that failed for a passing reason is tried again while the form
  /// stays open, with growing pauses; leaving or the next launch also send.
  void _scheduleSendRetry(RouteDraftSyncOutcome outcome) {
    final passing =
        outcome == RouteDraftSyncOutcome.offline ||
        outcome == RouteDraftSyncOutcome.timedOut ||
        outcome == RouteDraftSyncOutcome.failed;
    if (!passing) {
      _sendRetries = 0;
      return;
    }
    final pause = _sendRetryDelay * (1 << math.min(_sendRetries, 3));
    _sendRetries++;
    _sendRetry = Timer(pause, () => unawaited(_sendInBackground()));
  }

  void _reportOutcome(RouteDraftSyncOutcome outcome, {required bool explicit}) {
    switch (outcome) {
      case RouteDraftSyncOutcome.synced || RouteDraftSyncOutcome.upToDate:
        if (explicit) {
          _message('Черновик сохранён');
        }
      case RouteDraftSyncOutcome.notReady ||
          RouteDraftSyncOutcome.offline ||
          RouteDraftSyncOutcome.timedOut ||
          RouteDraftSyncOutcome.failed:
        if (explicit) {
          _message('Черновик сохранён на устройстве');
        }
      case RouteDraftSyncOutcome.blockedPlaces:
        _message('Некоторые точки больше недоступны — замените их');
      case RouteDraftSyncOutcome.blockedMedia:
        _message(
          'Не удалось отправить фото: их должно быть не больше '
          '${RoutePublishController.maxMedia}, а файлы — на месте',
        );
      case RouteDraftSyncOutcome.conflict:
        _quiet(() => state = state.copyWith(conflict: true));
      case RouteDraftSyncOutcome.heldBack ||
          RouteDraftSyncOutcome.blocked ||
          RouteDraftSyncOutcome.notOwner:
        break;
    }
  }

  /// A send that ran without this editor (after leaving, or from the sync
  /// service at launch) reports back what the editor should adopt.
  void _onSyncEvent(RouteDraftSyncEvent event) {
    if (!mounted) {
      return;
    }
    switch (event) {
      case MediaUploadedEvent():
        _quiet(() {
          state = state.copyWith(
            uploadsDone: _syncing
                ? math.min(state.uploadsDone + 1, state.uploadsTotal)
                : null,
            draft: state.draft.copyWith(
              media: [
                for (final item in state.draft.media)
                  item.id == event.localMediaId
                      ? item.copyWith(serverMediaId: event.serverMediaId)
                      : item,
              ],
            ),
          );
        });
      case DraftSyncedEvent(:final draft):
        if (draft.clientDraftId != state.draft.clientDraftId) {
          return;
        }
        _quiet(() {
          state = state.copyWith(
            draft: state.draft.copyWith(
              serverId: draft.serverId,
              publicationStatus: draft.publicationStatus,
              serverUpdatedAt: draft.serverUpdatedAt,
              lastSyncedAt: draft.lastSyncedAt,
              unsynced: draft.unsynced || _dirty,
              blockedReason: draft.blockedReason,
              blockedFingerprint: draft.blockedFingerprint,
              clearBlocked: draft.blockedReason == null,
            ),
          );
        });
        _refreshStatus();
    }
  }

  Future<void> _hydrate() async {
    await _restore();
    // Edits made while reading, with nothing stored to ask about, are saved
    // now like any other edit.
    if (mounted &&
        _dirty &&
        !state.isHydrating &&
        state.availableDraft == null &&
        state.draft.hasMeaningfulContent) {
      _onEdited();
    }
  }

  Future<void> _restore() async {
    try {
      final loaded = await _drafts.load();
      if (!mounted) {
        return;
      }
      if (loaded == null || !loaded.hasMeaningfulContent) {
        state = state.copyWith(isHydrating: false);
        unawaited(_loadServerDrafts());
        return;
      }
      final userId = _userId;
      // Somebody else's draft (an earlier account on this phone) is neither
      // shown nor sent: it is erased with its photo copies.
      if (userId != null &&
          loaded.ownerUserId != null &&
          loaded.ownerUserId != userId) {
        await _sync.discardLocal();
        if (mounted) {
          state = state.copyWith(isHydrating: false);
          unawaited(_loadServerDrafts());
        }
        return;
      }
      // Drafts written before drafts had an owner belong to whoever is here.
      final draft = loaded.ownerUserId == null && userId != null
          ? loaded.copyWith(
              ownerUserId: userId,
              clientDraftId: loaded.clientDraftId ?? newClientEventId(),
            )
          : loaded;
      final existing = await _withExistingMedia(draft);
      if (!mounted) {
        return;
      }
      unawaited(
        _mediaStore.purgeExpired(inUse: {for (final m in draft.media) m.path}),
      );
      // A route already through review is edited from its own card. From the
      // compose button it is not resumed as if it were a new draft; unsent
      // edits are asked about, anything else is simply gone.
      if (draft.isLiveRoute && !_editingExisting) {
        if (draft.unsynced) {
          state = state.copyWith(availableDraft: existing, isHydrating: false);
        } else {
          await _drafts.delete();
          state = state.copyWith(isHydrating: false);
        }
        unawaited(_loadServerDrafts());
        return;
      }
      if (_dirty || !_editingExisting) {
        // Opening the form offers the draft in a window with the other saved
        // drafts, rather than dropping the author into it unasked; typing
        // that landed before the draft loaded is not overwritten either.
        state = state.copyWith(availableDraft: existing, isHydrating: false);
      } else {
        // Editing a route from its own card: that route is what was asked for.
        _quiet(() {
          state = state.copyWith(
            draft: existing,
            isHydrating: false,
            restoredNotice: true,
          );
        });
        _refreshRoutePreview();
        _refreshStatus();
        unawaited(_sendPending());
      }
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

  /// What a previous session left unsent goes out now that the form is open.
  Future<void> _sendPending() async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    await _send(userId, explicit: false);
  }

  /// Drops photos whose file no longer exists.
  ///
  /// Drafts written before photos were copied somewhere durable still list
  /// paths into cleared temp directories; keeping them would show the author
  /// broken tiles they cannot remove or publish.
  Future<RouteDraft> _withExistingMedia(RouteDraft draft) async {
    if (draft.media.isEmpty) {
      return draft;
    }
    final media = <RouteMediaItem>[];
    for (final item in draft.media) {
      if (item.isAsset || item.isRemote) {
        // A file the server already stores is not on this device at all;
        // looking for it would drop every photo of a resumed draft.
        media.add(item);
        continue;
      }
      final resolved = await _mediaStore.resolve(item.path);
      if (resolved != null) {
        // Rewritten rather than merely kept: after a reinstall the stored
        // path is stale even though the file is there.
        media.add(item.copyWith(path: resolved));
      }
    }
    if (media.length == draft.media.length) {
      return draft;
    }
    _message('Часть фотографий из черновика больше недоступна');
    return draft.copyWith(media: media);
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
      // An empty form with saved drafts behind it offers them once, the way
      // a local draft is offered; after that they stay one tap away.
      final offer =
          !_draftsPromptShown &&
          drafts.isNotEmpty &&
          !_dirty &&
          state.availableDraft == null &&
          !state.draft.hasMeaningfulContent;
      if (offer) {
        _draftsPromptShown = true;
      }
      _quiet(
        () => state = state.copyWith(
          serverDrafts: drafts,
          draftsListOpen: offer ? true : null,
        ),
      );
    } on Object {
      // Offline or a failed call: the local draft is still offered.
    }
  }

  /// Opens one of the server drafts in the editor.
  ///
  /// Unsent edits are sent first, so they become one of the server drafts
  /// instead of being replaced. If they cannot be sent, the person is asked
  /// (see [RoutePublishState.replaceConfirmFor]) before anything is lost.
  Future<void> openServerDraft(
    String routeId, {
    bool confirmedReplace = false,
  }) async {
    if (state.isOpeningDraft) {
      return;
    }
    state = state.copyWith(isOpeningDraft: true, clearReplaceConfirm: true);
    try {
      if (!confirmedReplace && await _hasUnsentEdits()) {
        final handled = await _trySendBeforeReplace();
        if (!handled) {
          if (mounted) {
            state = state.copyWith(
              isOpeningDraft: false,
              replaceConfirmFor: routeId,
            );
          }
          return;
        }
      }
      final loaded = await _publication.loadForEdit(routeId);
      if (!mounted) {
        return;
      }
      final draft = loaded.copyWith(
        ownerUserId: _userId,
        clientDraftId: newClientEventId(),
        unsynced: false,
        updatedAt: DateTime.now().toUtc(),
      );
      _quiet(() {
        state = state.copyWith(
          draft: draft,
          isOpeningDraft: false,
          clearAvailableDraft: true,
          restoredNotice: false,
          draftsListOpen: false,
        );
      });
      _dirty = false;
      _refreshRoutePreview();
      _refreshStatus();
      await _drafts.save(draft);
    } on Object {
      if (mounted) {
        state = state.copyWith(isOpeningDraft: false);
        _message('Не удалось открыть черновик');
      }
    }
  }

  Future<bool> _hasUnsentEdits() async {
    final draft = state.draft;
    return draft.hasMeaningfulContent && (draft.unsynced || _dirty);
  }

  /// True when the current draft is safe on the server (or there is nothing to
  /// lose); false when opening another one would replace unsent edits.
  Future<bool> _trySendBeforeReplace() async {
    final userId = _userId;
    if (userId == null) {
      return false;
    }
    await _persistLocal();
    final outcome = await _send(userId, explicit: !state.draft.isLiveRoute);
    return outcome == RouteDraftSyncOutcome.synced ||
        outcome == RouteDraftSyncOutcome.upToDate;
  }

  void continueDraft() {
    final draft = state.availableDraft;
    if (draft == null) {
      return;
    }
    _quiet(() {
      state = state.copyWith(
        draft: draft,
        clearAvailableDraft: true,
        draftsListOpen: false,
      );
    });
    // Opening a draft has to draw its map too. Previously the preview was
    // only computed from the point-editing path, so a restored draft showed
    // the placeholder until the author happened to move a point.
    _refreshRoutePreview();
    _refreshStatus();
    // What a previous session left unsent goes out now that it is open.
    if (draft.unsynced && !_dirty) {
      unawaited(_sendPending());
    }
  }

  /// Shows the saved drafts in the window over the form.
  void openDraftsList() {
    _draftsPromptShown = true;
    _quiet(() => state = state.copyWith(draftsListOpen: true));
  }

  /// Closes the drafts window and keeps the form as it is.
  void closeDraftsList() {
    if (state.draftsListOpen) {
      _quiet(() => state = state.copyWith(draftsListOpen: false));
    }
  }

  void dismissRestoredNotice() {
    if (state.restoredNotice) {
      _quiet(() => state = state.copyWith(restoredNotice: false));
    }
  }

  /// Starts an empty form. Only the copy on this device goes: the draft already
  /// saved on the server stays in the list of drafts.
  Future<void> startNewDraft() async {
    _autosave?.cancel();
    _localRetry?.cancel();
    _dirty = false;
    _quiet(() {
      state = state.copyWith(
        draft: const RouteDraft(),
        clearAvailableDraft: true,
        draftsListOpen: false,
        restoredNotice: false,
        saveStatus: DraftSaveStatus.idle,
      );
    });
    try {
      await _drafts.delete();
    } catch (_) {
      _message(
        'Новый маршрут начат, но локальный черновик удалить не удалось.',
      );
    }
    unawaited(_loadServerDrafts());
  }

  /// Deletes a draft that lives on the server (from the list of drafts).
  Future<void> discardServerDraft(String routeId) async {
    try {
      await _publication.discardDraft(routeId);
      if (mounted) {
        _quiet(() {
          state = state.copyWith(
            serverDrafts: [
              for (final route in state.serverDrafts)
                if (route.id != routeId) route,
            ],
          );
        });
      }
    } on AppFailure {
      _message('Не удалось удалить черновик');
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
  ///
  /// Выбрать можно сразу несколько фото: сколько ещё влезает до [maxMedia],
  /// столько и разрешаем взять, а кадрирование получает всю пачку разом и
  /// возвращает её в том же порядке.
  Future<void> addMedia(
    RouteMediaSource source, {
    Future<List<String>?> Function(List<String> paths)? crop,
  }) async {
    if (state.isPickingMedia) {
      return;
    }
    final room = maxMedia - state.draft.media.length;
    if (room <= 0) {
      _message('Можно добавить не больше $maxMedia файлов');
      return;
    }
    state = state.copyWith(isPickingMedia: true, clearMediaError: true);
    try {
      final picked = await _mediaPicker.pickMany(source, limit: room);
      if (picked.isEmpty || !mounted) {
        return;
      }
      var items = picked;
      final images = [
        for (final item in picked)
          if (item.kind == RouteMediaKind.image) item,
      ];
      if (crop != null && images.isNotEmpty) {
        final cropped = await crop([for (final item in images) item.path]);
        if (cropped == null || !mounted) {
          return;
        }
        // The editor may hand back fewer files than it was given — a photo
        // it could not decode is dropped rather than failing the batch — so
        // pair them up by position and keep only what came back.
        items = [
          for (var index = 0; index < cropped.length; index++)
            images[index].copyWith(path: cropped[index]),
        ];
      }
      final added = <RouteMediaItem>[];
      for (final item in items) {
        // The picker's and the cropper's files live in directories the OS may
        // clear; a draft must not point at them.
        final kept = item.copyWith(path: await _mediaStore.keep(item.path));
        if (!mounted) {
          return;
        }
        final known = [...state.draft.media, ...added];
        if (known.any((existing) => existing.path == kept.path)) {
          continue;
        }
        added.add(kept);
      }
      if (added.isEmpty) {
        _message('Эти файлы уже добавлены');
        return;
      }
      state = state.copyWith(
        draft: state.draft.copyWith(media: [...state.draft.media, ...added]),
        clearMediaError: true,
      );
      if (picked.length == room && room < maxMedia) {
        _message('Добавлено $room — это максимум для этого маршрута');
      }
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
    // The car tag changes the road line itself (spec 14b).
    if (filter == carRouteTag) _refreshRoutePreview();
  }

  /// «Закончить день здесь» on a stop, or take it back (spec 14a).
  void toggleDayBreak(String placeId) {
    final breaks = [...state.draft.dayBreaks];
    if (!breaks.remove(placeId)) breaks.add(placeId);
    state = state.copyWith(draft: state.draft.copyWith(dayBreaks: breaks));
  }

  void setPace(TravelPace pace) {
    state = state.copyWith(draft: state.draft.copyWith(pace: pace));
  }

  void setDifficulty(int value) {
    state = state.copyWith(
      draft: state.draft.copyWith(difficulty: value.clamp(1, 5)),
    );
  }

  /// The explicit "Сохранить черновик": writes to the device and sends to the
  /// server now, also for a route already through review (the screen has
  /// warned that this puts it back on moderation).
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
      _autosave?.cancel();
      await _persistLocal();
      final userId = _userId;
      if (userId == null) {
        _message('Черновик сохранён на устройстве');
        return;
      }
      await _send(userId, explicit: true);
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
      _autosave?.cancel();
      await _persistLocal();
      final userId = _userId;
      if (userId == null) {
        _message('Войдите в аккаунт, чтобы опубликовать маршрут');
        return null;
      }
      final outcome = await _send(userId, explicit: true);
      if (outcome != RouteDraftSyncOutcome.synced) {
        if (outcome != RouteDraftSyncOutcome.conflict) {
          _message('Не удалось опубликовать маршрут. Черновик сохранён.');
        }
        return null;
      }
      // The send brought the stored draft up to date (server id, photo ids).
      final prepared = await _drafts.load() ?? state.draft;
      final submittedReceipt = await _publication.submit(prepared);
      await _drafts.delete();
      _dirty = false;
      if (mounted) {
        _quiet(() {
          state = state.copyWith(
            draft: prepared.copyWith(
              serverId: submittedReceipt.id,
              publicationStatus: submittedReceipt.status,
              serverUpdatedAt: submittedReceipt.updatedAt,
              unsynced: false,
            ),
            clearAvailableDraft: true,
          );
        });
        _message('Маршрут отправлен на модерацию');
      }
      return submittedReceipt.id;
    } on AppFailure catch (error) {
      _message(error.message);
      return null;
    } catch (_) {
      _message('Не удалось опубликовать маршрут. Черновик сохранён.');
      return null;
    } finally {
      if (mounted) {
        state = state.copyWith(isPublishing: false);
      }
    }
  }

  /// The server copy changed elsewhere: keep this version as a new draft.
  Future<void> resolveConflictKeepMine() async {
    final mine = state.draft;
    final fresh = mine.copyWith(
      clearServer: true,
      clientDraftId: newClientEventId(),
      publicationStatus: RoutePublicationStatus.draft,
      unsynced: true,
      clearBlocked: true,
      // Photos already on the server belong to the other draft; the ones the
      // device holds are uploaded again into the new one.
      media: [
        for (final item in mine.media)
          if (!item.isRemote) item.withoutServerId(),
      ],
    );
    _quiet(() => state = state.copyWith(draft: fresh, conflict: false));
    _dirty = true;
    await saveDraft();
  }

  /// The server copy changed elsewhere: take that version.
  Future<void> resolveConflictTakeServer() async {
    final serverId = state.draft.serverId;
    if (serverId == null) {
      _quiet(() => state = state.copyWith(conflict: false));
      return;
    }
    try {
      final loaded = await _publication.loadForEdit(serverId);
      if (!mounted) {
        return;
      }
      final draft = loaded.copyWith(
        ownerUserId: _userId,
        clientDraftId: state.draft.clientDraftId ?? newClientEventId(),
        unsynced: false,
        updatedAt: DateTime.now().toUtc(),
      );
      _quiet(() => state = state.copyWith(draft: draft, conflict: false));
      _dirty = false;
      _refreshRoutePreview();
      _refreshStatus();
      await _drafts.save(draft);
    } on Object {
      _message('Не удалось загрузить версию с сервера');
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
    _autosave?.cancel();
    _sendRetry?.cancel();
    _localRetry?.cancel();
    unawaited(_syncSubscription?.cancel());
    // Leaving with edits that were not written or sent yet: hand them over
    // before the state goes away. Nothing here waits for the screen.
    if (_mode == RoutePublishMode.production &&
        !state.isHydrating &&
        state.draft.hasMeaningfulContent &&
        (_dirty || state.draft.unsynced)) {
      unawaited(_handOff(_stamped(state.draft), write: _dirty));
    }
    super.dispose();
  }

  Future<void> _handOff(RouteDraft draft, {required bool write}) async {
    if (write) {
      try {
        await _drafts.save(draft);
      } on Object {
        return;
      }
    }
    final userId = _userId;
    if (userId != null) {
      unawaited(_sync.sync(userId, draft));
    }
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
        final preview = await _publication.previewRoute(
          placeIds: placeIds,
          transportMode: state.draft.filters.contains(carRouteTag)
              ? 'car'
              : 'walk',
        );
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
