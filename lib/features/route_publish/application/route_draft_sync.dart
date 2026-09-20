import 'dart:async';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/features/route_publish/data/route_draft_media_store.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/domain/route_publish_repository.dart';

/// How one attempt to send the local draft to the server ended.
enum RouteDraftSyncOutcome {
  /// The server has the draft now.
  synced,

  /// Nothing to send: no edits since the last send.
  upToDate,

  /// Title, start and finish are not there yet; the draft stays on the device.
  notReady,

  /// A live (in review or published) route: only an explicit save may send it,
  /// because saving puts it back on moderation.
  heldBack,

  /// The draft belongs to somebody else, or the session ended meanwhile.
  notOwner,

  /// No connection. The draft stays marked unsent and is tried again later.
  offline,

  /// The server refused for good until the places change.
  blockedPlaces,

  /// The server refused for good until the photos change.
  blockedMedia,

  /// Already known to fail for the same places/photos: not tried again.
  blocked,

  /// The server copy changed on another device after this one was based on it.
  conflict,

  /// Any other failure; kept unsent and tried again later.
  failed,
}

/// Something a live editor should adopt from a send that ran without it.
sealed class RouteDraftSyncEvent {
  const RouteDraftSyncEvent();
}

/// One photo reached the server and got this id there.
final class MediaUploadedEvent extends RouteDraftSyncEvent {
  const MediaUploadedEvent({
    required this.localMediaId,
    required this.serverMediaId,
  });

  final String localMediaId;
  final String serverMediaId;
}

/// The draft was saved on the server (or the attempt changed its bookkeeping).
final class DraftSyncedEvent extends RouteDraftSyncEvent {
  const DraftSyncedEvent(this.draft);

  /// The stored draft after the send, edits made meanwhile included.
  final RouteDraft draft;
}

/// Sends the local draft to the server, one attempt at a time, outside any
/// screen.
///
/// The editor's controller dies with the screen, but leaving the screen (or
/// backgrounding the app) is exactly when the draft must still get to the
/// server. So this lives for the whole session, takes the draft as a value,
/// and is tied to the account that started it: [cancel] (called when the
/// session is cleared) stops it from touching anything afterwards.
class RouteDraftSyncService {
  RouteDraftSyncService({
    required this._drafts,
    required this._publication,
    required this._mediaStore,
    required this._storage,
  });

  static const _signOutKey = 'route_publish.signout_pending';

  final RouteDraftRepository _drafts;
  final RoutePublicationRepository _publication;
  final RouteDraftMediaStore _mediaStore;
  final SecureStoragePort _storage;

  final _events = StreamController<RouteDraftSyncEvent>.broadcast();
  Stream<RouteDraftSyncEvent> get events => _events.stream;

  // Bumped by [cancel]: an attempt that started under an older number stops
  // writing anything, so it cannot leak into the next account.
  int _generation = 0;
  Future<void> _tail = Future<void>.value();

  /// Stops in-flight sends from writing and makes queued ones no-ops.
  void cancel() => _generation++;

  /// Sends [snapshot] for [userId]. [explicit] is a person pressing save or
  /// publish: it also sends a live route and retries a blocked draft.
  Future<RouteDraftSyncOutcome> sync(
    String userId,
    RouteDraft snapshot, {
    bool explicit = false,
  }) {
    final generation = _generation;
    final completer = Completer<RouteDraftSyncOutcome>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(
          await _run(userId, snapshot, generation, explicit: explicit),
        );
      } on Object {
        completer.complete(RouteDraftSyncOutcome.failed);
      }
    });
    return completer.future;
  }

  /// At launch or when the screen opens: sends what a previous session left
  /// behind (the app was killed, or there was no network).
  Future<RouteDraftSyncOutcome?> syncPending(String userId) async {
    final stored = await _drafts.load();
    if (stored == null || !stored.hasMeaningfulContent) {
      return null;
    }
    return sync(userId, stored);
  }

  /// Before signing out: tries to get an unsent draft onto the server so that
  /// erasing the device copy loses nothing. False means there is unsent work
  /// that could not be saved (offline, incomplete, or a live route whose edits
  /// only an explicit save may send), and the person must decide.
  Future<bool> trySendUnsent(String userId) async {
    final stored = await _drafts.load();
    if (stored == null || !stored.hasMeaningfulContent) {
      return true;
    }
    if (stored.ownerUserId != null && stored.ownerUserId != userId) {
      return true;
    }
    if (!stored.unsynced) {
      return true;
    }
    final outcome = await sync(userId, stored);
    return outcome == RouteDraftSyncOutcome.synced ||
        outcome == RouteDraftSyncOutcome.upToDate;
  }

  /// Written just before the session is cleared, so a kill halfway through the
  /// sign-out still ends with the device copy erased at the next start.
  Future<void> markSignOutPending() async {
    try {
      await _storage.write(key: _signOutKey, value: '1');
    } on Object {
      // Without the flag the worst case is the draft surviving a kill.
    }
  }

  Future<void> finishInterruptedSignOut() async {
    try {
      if (await _storage.read(key: _signOutKey) == null) {
        return;
      }
      await discardLocal();
      await _storage.delete(key: _signOutKey);
    } on Object {
      // Tried again at the next start.
    }
  }

  Future<void> clearSignOutFlag() async {
    try {
      await _storage.delete(key: _signOutKey);
    } on Object {
      // Nothing to do.
    }
  }

  /// Erases the local draft and its photo copies (sign-out, foreign draft).
  Future<void> discardLocal() async {
    try {
      await _drafts.delete();
    } on Object {
      // Nothing more to do; the next start tries the cleanup again.
    }
    await _mediaStore.clearAll();
  }

  Future<RouteDraftSyncOutcome> _run(
    String userId,
    RouteDraft snapshot,
    int generation, {
    required bool explicit,
  }) async {
    if (generation != _generation) {
      return RouteDraftSyncOutcome.notOwner;
    }
    if (snapshot.ownerUserId != null && snapshot.ownerUserId != userId) {
      return RouteDraftSyncOutcome.notOwner;
    }
    if (snapshot.isLiveRoute && !explicit) {
      return RouteDraftSyncOutcome.heldBack;
    }
    if (!snapshot.unsynced && !explicit) {
      return RouteDraftSyncOutcome.upToDate;
    }
    final ready =
        snapshot.title.trim().isNotEmpty &&
        snapshot.start != null &&
        snapshot.finish != null;
    if (!ready) {
      return RouteDraftSyncOutcome.notReady;
    }
    if (snapshot.isBlocked && !explicit) {
      return RouteDraftSyncOutcome.blocked;
    }
    if (!explicit) {
      // The stored copy is the truth: a send that already covered these edits
      // (the screen's flush and its dispose both ask) is not repeated.
      final stored = await _drafts.load();
      final covered =
          stored != null &&
          !stored.unsynced &&
          stored.clientDraftId == snapshot.clientDraftId &&
          !(snapshot.updatedAt != null &&
              stored.updatedAt != null &&
              snapshot.updatedAt!.isAfter(stored.updatedAt!));
      if (covered) {
        return RouteDraftSyncOutcome.upToDate;
      }
    }

    try {
      final receipt = await _publication.saveDraft(
        snapshot,
        onMediaUploaded: (localId, serverId) {
          if (generation != _generation) {
            return;
          }
          unawaited(_recordUpload(localId, serverId, generation));
        },
      );
      if (generation != _generation) {
        return RouteDraftSyncOutcome.notOwner;
      }
      await _recordSaved(snapshot, receipt, generation);
      return RouteDraftSyncOutcome.synced;
    } on NetworkFailure {
      return RouteDraftSyncOutcome.offline;
    } on AppFailure catch (error) {
      if (generation != _generation) {
        return RouteDraftSyncOutcome.notOwner;
      }
      return _classify(error, snapshot, generation);
    }
  }

  Future<RouteDraftSyncOutcome> _classify(
    AppFailure error,
    RouteDraft snapshot,
    int generation,
  ) async {
    switch (error.code) {
      case 'invalid_route_place' || 'invalid_route_region':
        await _markBlocked(
          'places',
          (draft) => draft.placesFingerprint,
          generation,
        );
        return RouteDraftSyncOutcome.blockedPlaces;
      case 'invalid_route_media' || 'route_media_limit':
        await _markBlocked(
          'media',
          (draft) => draft.mediaFingerprint,
          generation,
        );
        return RouteDraftSyncOutcome.blockedMedia;
      case 'draft_conflict':
        return RouteDraftSyncOutcome.conflict;
      default:
        // Includes `draft_busy` (a racing save of the same draft): transient.
        return RouteDraftSyncOutcome.failed;
    }
  }

  Future<void> _markBlocked(
    String reason,
    String Function(RouteDraft draft) fingerprint,
    int generation,
  ) async {
    final stored = await _drafts.load();
    if (stored == null || generation != _generation) {
      return;
    }
    final blocked = stored.copyWith(
      blockedReason: reason,
      blockedFingerprint: fingerprint(stored),
    );
    await _drafts.save(blocked);
    _events.add(DraftSyncedEvent(blocked));
  }

  /// Marks one photo as uploaded in the stored draft right away, so a send
  /// cut short does not send it again.
  Future<void> _recordUpload(
    String localId,
    String serverId,
    int generation,
  ) async {
    _events.add(
      MediaUploadedEvent(localMediaId: localId, serverMediaId: serverId),
    );
    final stored = await _drafts.load();
    if (stored == null || generation != _generation) {
      return;
    }
    if (!stored.media.any((item) => item.id == localId)) {
      return;
    }
    await _drafts.save(
      stored.copyWith(
        media: [
          for (final item in stored.media)
            item.id == localId ? item.copyWith(serverMediaId: serverId) : item,
        ],
      ),
    );
  }

  Future<void> _recordSaved(
    RouteDraft sent,
    RoutePublicationReceipt receipt,
    int generation,
  ) async {
    final stored = await _drafts.load();
    // Gone (the person started over, or signed out) while the send ran:
    // nothing local to update, and it must not be brought back.
    if (stored == null || generation != _generation) {
      return;
    }
    // Edits made while the send was running are not in what the server got.
    final editedMeanwhile =
        sent.updatedAt != null &&
        stored.updatedAt != null &&
        stored.updatedAt!.isAfter(sent.updatedAt!);
    final saved = stored.copyWith(
      serverId: receipt.id,
      publicationStatus: receipt.status,
      serverUpdatedAt: receipt.updatedAt,
      lastSyncedAt: DateTime.now().toUtc(),
      unsynced: editedMeanwhile,
      clearBlocked: true,
    );
    await _drafts.save(saved);
    _events.add(DraftSyncedEvent(saved));
  }

  void dispose() {
    _generation++;
    unawaited(_events.close());
  }
}
