import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/storage/memory_secure_storage.dart';
import 'package:tourism_mobile/features/route_publish/application/route_draft_sync.dart';
import 'package:tourism_mobile/features/route_publish/application/route_publish_controller.dart';
import 'package:tourism_mobile/features/route_publish/data/route_draft_media_store.dart';
import 'package:tourism_mobile/features/route_publish/data/route_media_picker.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/domain/route_publish_repository.dart';
import 'package:tourism_mobile/features/routes/data/mock_routes_repository.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

const _delay = Duration(milliseconds: 30);
const _wait = Duration(milliseconds: 120);

const _start = RouteLocation(
  id: 'p1',
  name: 'Старт',
  subtitle: 'Крым',
  lat: 44.5,
  lng: 34,
);
const _finish = RouteLocation(
  id: 'p2',
  name: 'Финиш',
  subtitle: 'Крым',
  lat: 44.6,
  lng: 34.1,
);

final class _Drafts implements RouteDraftRepository {
  RouteDraft? value;
  int writes = 0;
  int failNext = 0;
  Duration slow = Duration.zero;

  /// A slow storage read (the Keychain on a cold start).
  Duration slowLoad = Duration.zero;

  @override
  Future<RouteDraft?> load() async {
    if (slowLoad > Duration.zero) {
      await Future<void>.delayed(slowLoad);
    }
    return value;
  }

  @override
  Future<void> save(RouteDraft draft) async {
    if (slow > Duration.zero) {
      await Future<void>.delayed(slow);
    }
    if (failNext > 0) {
      failNext--;
      throw StateError('disk full');
    }
    writes++;
    value = draft;
  }

  @override
  Future<void> delete() async => value = null;
}

final class _Store implements RouteDraftMediaStore {
  bool cleared = false;

  @override
  Future<String> keep(String path) async => path;

  @override
  Future<void> purgeExpired({Set<String> inUse = const {}}) async {}

  @override
  Future<void> clearAll() async => cleared = true;

  @override
  Future<String?> resolve(String path) async => path;
}

final class _Publication implements RoutePublicationRepository {
  final sent = <RouteDraft>[];
  Object? failure;
  Duration slow = Duration.zero;
  bool uploadPhotos = false;

  @override
  Future<RoutePublicationReceipt> saveDraft(
    RouteDraft draft, {
    void Function(String localMediaId, String serverMediaId)? onMediaUploaded,
  }) async {
    sent.add(draft);
    if (slow > Duration.zero) {
      await Future<void>.delayed(slow);
    }
    final error = failure;
    if (error != null) {
      throw error;
    }
    if (uploadPhotos) {
      for (final item in draft.media) {
        if (!item.isOnServer) {
          onMediaUploaded?.call(item.id, 'srv-${item.id}');
        }
      }
    }
    return RoutePublicationReceipt(
      id: draft.serverId ?? 'route-1',
      status: RoutePublicationStatus.draft,
      updatedAt: DateTime.utc(2026, 9, 20, 12, sent.length),
    );
  }

  @override
  Future<RoutePublicationReceipt> submit(RouteDraft draft) async =>
      RoutePublicationReceipt(
        id: draft.serverId!,
        status: RoutePublicationStatus.pendingReview,
        updatedAt: DateTime.utc(2026),
      );

  @override
  Future<void> discardDraft(String routeId) async {}

  @override
  Future<RouteDraft> loadForEdit(String routeId) async => RouteDraft(
    serverId: routeId,
    title: 'С сервера',
    start: _start,
    finish: _finish,
  );

  @override
  Future<RoutePublicationReceipt> withdraw(String routeId) async =>
      throw UnimplementedError();

  @override
  Future<RouteDraftPreview> previewRoute({
    required List<String> placeIds,
    String transportMode = 'walk',
  }) async => throw UnimplementedError();
}

final class _Picker implements RouteMediaPicker {
  @override
  Future<RouteMediaItem?> pick(RouteMediaSource source) async => null;

  @override
  Future<List<RouteMediaItem>> pickMany(
    RouteMediaSource source, {
    required int limit,
  }) async => const [];
}

final class _MyRoutes extends MockRoutesRepository {
  _MyRoutes(this.drafts);

  final List<RouteSummary> drafts;

  @override
  Future<RouteListPage> listMyRoutes() async =>
      RouteListPage(items: drafts, total: drafts.length, limit: 100, offset: 0);
}

RouteSummary _serverDraft(String id, {String? source}) => RouteSummary(
  id: id,
  name: 'Черновик $id',
  slug: id,
  shortDescription: '',
  stopsCount: 2,
  source: source,
  publicationStatus: 'draft',
);

class _Rig {
  _Rig({
    RouteDraft? stored,
    String? userId = 'user-1',
    bool editingExisting = false,
    List<RouteSummary> serverDrafts = const [],
  }) : drafts = _Drafts()..value = stored,
       publication = _Publication(),
       store = _Store() {
    sync = RouteDraftSyncService(
      drafts: drafts,
      publication: publication,
      mediaStore: store,
      storage: MemorySecureStorage(),
    );
    controller = RoutePublishController(
      mode: RoutePublishMode.production,
      userId: userId,
      editingExisting: editingExisting,
      autosaveDelay: _delay,
      sendRetryDelay: const Duration(milliseconds: 60),
      drafts: drafts,
      mediaPicker: _Picker(),
      mediaStore: store,
      publication: publication,
      sync: sync,
      routes: _MyRoutes(serverDrafts),
    );
  }

  final _Drafts drafts;
  final _Publication publication;
  final _Store store;
  late final RouteDraftSyncService sync;
  late final RoutePublishController controller;

  Future<void> ready() => Future<void>.delayed(const Duration(milliseconds: 5));

  void complete() {
    controller
      ..setTitle('Маршрут')
      ..setStart(_start)
      ..setFinish(_finish);
  }
}

void main() {
  test(
    'an edit is written to the device after a pause, not sent to the server',
    () async {
      final rig = _Rig();
      addTearDown(rig.controller.dispose);
      await rig.ready();

      rig.controller.setTitle('Маршрут');
      expect(rig.drafts.value, isNull, reason: 'not before the pause');
      await Future<void>.delayed(_wait);

      expect(rig.drafts.value?.title, 'Маршрут');
      expect(rig.drafts.value?.ownerUserId, 'user-1');
      expect(rig.drafts.value?.clientDraftId, isNotEmpty);
      expect(rig.drafts.value?.unsynced, isTrue);
      expect(rig.publication.sent, isEmpty);
      expect(rig.controller.state.saveStatus, DraftSaveStatus.savedLocal);
    },
  );

  test('typing while the stored draft is still read is saved', () async {
    final rig = _Rig();
    rig.drafts.slowLoad = const Duration(milliseconds: 60);
    addTearDown(rig.controller.dispose);

    // The form is already on screen while the storage read runs.
    rig.controller.setTitle('Маршрут');
    expect(rig.drafts.writes, 0, reason: 'nothing written before the read');
    await Future<void>.delayed(_wait * 2);

    expect(rig.controller.state.isHydrating, isFalse);
    expect(rig.drafts.value?.title, 'Маршрут');
    expect(rig.controller.state.saveStatus, DraftSaveStatus.savedLocal);
  });

  test(
    'typing over a stored draft that is still read asks, and keeps both',
    () async {
      final rig = _Rig(
        stored: const RouteDraft(
          ownerUserId: 'user-1',
          clientDraftId: 'old',
          title: 'Старый',
        ),
      );
      rig.drafts.slowLoad = const Duration(milliseconds: 60);
      addTearDown(rig.controller.dispose);

      rig.controller.setTitle('Новый');
      await Future<void>.delayed(_wait);

      expect(rig.controller.state.draft.title, 'Новый');
      expect(rig.controller.state.availableDraft?.title, 'Старый');
      expect(rig.drafts.value?.title, 'Старый', reason: 'not replaced unseen');
    },
  );

  test('a burst of edits ends with the last one on the device', () async {
    final rig = _Rig();
    addTearDown(rig.controller.dispose);
    await rig.ready();

    for (final text in ['М', 'Ма', 'Мар', 'Марш']) {
      rig.controller.setTitle(text);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(_wait);

    expect(rig.drafts.value?.title, 'Марш');
    expect(rig.drafts.writes, 1, reason: 'one debounced write');
  });

  test('leaving hands the draft to the sync service, which sends it', () async {
    final rig = _Rig();
    addTearDown(rig.controller.dispose);
    await rig.ready();
    rig.complete();

    await rig.controller.flush();
    await Future<void>.delayed(_wait);

    expect(rig.publication.sent, hasLength(1));
    expect(rig.drafts.value?.serverId, 'route-1');
    expect(rig.drafts.value?.unsynced, isFalse);
    expect(rig.drafts.value?.serverUpdatedAt, isNotNull);
  });

  group('a failed send says why and is tried again', () {
    for (final (failure, status) in [
      (const NetworkFailure(), DraftSaveStatus.offline),
      (
        const NetworkFailure('timed out', NetworkFailure.timeoutCode),
        DraftSaveStatus.timedOut,
      ),
      (const UnexpectedFailure('boom'), DraftSaveStatus.sendFailed),
    ]) {
      test('${failure.runtimeType} ${failure.code}', () async {
        final rig = _Rig();
        addTearDown(rig.controller.dispose);
        await rig.ready();
        rig.complete();
        rig.publication.failure = failure;

        await rig.controller.flush();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(rig.controller.state.saveStatus, status);

        // The server is back: the retry goes out on its own.
        rig.publication.failure = null;
        await Future<void>.delayed(_wait * 2);
        expect(rig.publication.sent.length, greaterThanOrEqualTo(2));
        expect(rig.controller.state.saveStatus, DraftSaveStatus.synced);
      });
    }
  });

  test('a send with photos counts them as they go', () async {
    final rig = _Rig();
    addTearDown(rig.controller.dispose);
    await rig.ready();
    rig.complete();
    rig.publication
      ..slow = const Duration(milliseconds: 60)
      ..uploadPhotos = true;
    rig.controller.state = rig.controller.state.copyWith(
      draft: rig.controller.state.draft.copyWith(
        media: const [
          RouteMediaItem(
            id: 'm1',
            path: '/x/a.jpg',
            kind: RouteMediaKind.image,
          ),
          RouteMediaItem(
            id: 'm2',
            path: '/x/b.jpg',
            kind: RouteMediaKind.image,
          ),
        ],
      ),
    );

    unawaited(rig.controller.flush());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(rig.controller.state.saveStatus, DraftSaveStatus.syncing);
    expect(rig.controller.state.uploadsTotal, 2);
    expect(rig.controller.state.uploadsDone, 0);

    await Future<void>.delayed(_wait);
    expect(rig.controller.state.saveStatus, DraftSaveStatus.synced);
    expect(rig.controller.state.uploadsTotal, 0);
  });

  test('an unchanged draft is not sent again', () async {
    final rig = _Rig();
    addTearDown(rig.controller.dispose);
    await rig.ready();
    rig.complete();

    await rig.controller.flush();
    await Future<void>.delayed(_wait);
    await rig.controller.flush();
    await Future<void>.delayed(_wait);

    expect(rig.publication.sent, hasLength(1));
  });

  test('disposing with edits still pending writes and sends them', () async {
    final rig = _Rig();
    await rig.ready();
    rig.complete();

    rig.controller.dispose();
    await Future<void>.delayed(_wait * 2);

    expect(rig.drafts.value?.title, 'Маршрут');
    expect(rig.publication.sent, hasLength(1));
  });

  test('an edit made while a write runs is not dropped', () async {
    final rig = _Rig();
    addTearDown(rig.controller.dispose);
    await rig.ready();
    rig.drafts.slow = const Duration(milliseconds: 60);

    rig.controller.setTitle('Первый');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    rig.controller.setTitle('Второй');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(rig.drafts.value?.title, 'Второй');
  });

  test('a failed device write is never reported as saved', () async {
    final rig = _Rig();
    addTearDown(rig.controller.dispose);
    await rig.ready();
    rig.drafts.failNext = 1;

    rig.controller.setTitle('Маршрут');
    await Future<void>.delayed(_wait);

    expect(rig.controller.state.saveStatus, DraftSaveStatus.localFailed);
    expect(rig.drafts.value, isNull);
  });

  test('a draft of another account is erased, not restored or sent', () async {
    final rig = _Rig(
      stored: const RouteDraft(title: 'Чужой', ownerUserId: 'someone-else'),
    );
    addTearDown(rig.controller.dispose);
    await rig.ready();

    expect(rig.controller.state.draft.title, isEmpty);
    expect(rig.drafts.value, isNull);
    expect(rig.store.cleared, isTrue);
    expect(rig.publication.sent, isEmpty);
  });

  test(
    'a draft from before owners existed is adopted by the person here',
    () async {
      final rig = _Rig(stored: const RouteDraft(title: 'Старый черновик'));
      addTearDown(rig.controller.dispose);
      await rig.ready();

      expect(rig.controller.state.availableDraft?.title, 'Старый черновик');
      rig.controller.continueDraft();
      expect(rig.controller.state.draft.title, 'Старый черновик');
      expect(rig.controller.state.draft.ownerUserId, 'user-1');
    },
  );

  group('saved drafts on entry', () {
    test('an empty form with drafts on the server offers them once', () async {
      final rig = _Rig(serverDrafts: [_serverDraft('a'), _serverDraft('b')]);
      addTearDown(rig.controller.dispose);
      await rig.ready();

      expect(rig.controller.state.availableDraft, isNull);
      expect(rig.controller.state.draftsListOpen, isTrue);
      expect(rig.controller.state.serverDrafts, hasLength(2));

      rig.controller.closeDraftsList();
      await rig.controller.startNewDraft();
      expect(
        rig.controller.state.draftsListOpen,
        isFalse,
        reason: 'reloading the list after starting over does not ask again',
      );

      rig.controller.openDraftsList();
      expect(rig.controller.state.draftsListOpen, isTrue);
    });

    test('a local draft is offered in the window, not the list', () async {
      final rig = _Rig(
        stored: const RouteDraft(ownerUserId: 'user-1', title: 'Мой'),
        serverDrafts: [_serverDraft('a')],
      );
      addTearDown(rig.controller.dispose);
      await rig.ready();

      expect(rig.controller.state.availableDraft?.title, 'Мой');
      expect(rig.controller.state.draftsListOpen, isFalse);
    });

    test('from a route card the route opens straight away', () async {
      final rig = _Rig(
        stored: const RouteDraft(ownerUserId: 'user-1', title: 'Свой'),
        editingExisting: true,
      );
      addTearDown(rig.controller.dispose);
      await rig.ready();

      expect(rig.controller.state.availableDraft, isNull);
      expect(rig.controller.state.draft.title, 'Свой');
    });
  });

  group('a route already through review', () {
    RouteDraft live({bool unsynced = false}) => RouteDraft(
      serverId: 'live-route',
      publicationStatus: RoutePublicationStatus.published,
      title: 'Живой',
      start: _start,
      finish: _finish,
      ownerUserId: 'user-1',
      clientDraftId: 'client-key-1',
      unsynced: unsynced,
    );

    test(
      'from the compose button its copy is dropped, or asked about if unsent',
      () async {
        final clean = _Rig(stored: live());
        addTearDown(clean.controller.dispose);
        await clean.ready();
        expect(clean.controller.state.draft.title, isEmpty);
        expect(clean.drafts.value, isNull);

        final unsent = _Rig(stored: live(unsynced: true));
        addTearDown(unsent.controller.dispose);
        await unsent.ready();
        expect(unsent.controller.state.draft.title, isEmpty);
        expect(unsent.controller.state.availableDraft?.title, 'Живой');
      },
    );

    test(
      'edited from its card it is saved locally only, sent by the button',
      () async {
        final rig = _Rig(stored: live(), editingExisting: true);
        addTearDown(rig.controller.dispose);
        await rig.ready();
        expect(rig.controller.state.draft.title, 'Живой');

        rig.controller.setTitle('Живой, правка');
        await rig.controller.flush();
        await Future<void>.delayed(_wait);
        expect(rig.drafts.value?.title, 'Живой, правка');
        expect(rig.publication.sent, isEmpty, reason: 'never on its own');

        await rig.controller.saveDraft();
        expect(rig.publication.sent, hasLength(1));
      },
    );
  });

  test('a conflict is reported and "keep mine" saves a new draft', () async {
    final rig = _Rig();
    addTearDown(rig.controller.dispose);
    await rig.ready();
    rig.complete();
    await rig.controller.saveDraft();
    expect(rig.controller.state.draft.serverId, 'route-1');

    rig.publication.failure = const UnexpectedFailure(
      'changed elsewhere',
      'draft_conflict',
    );
    rig.controller.setTitle('Моя версия');
    await rig.controller.saveDraft();
    expect(rig.controller.state.conflict, isTrue);

    rig.publication.failure = null;
    await rig.controller.resolveConflictKeepMine();

    expect(rig.controller.state.conflict, isFalse);
    final last = rig.publication.sent.last;
    expect(last.serverId, isNull, reason: 'a new draft, not an overwrite');
    expect(last.clientDraftId, isNot(rig.publication.sent.first.clientDraftId));
    expect(last.title, 'Моя версия');
  });

  test(
    'unavailable places are reported once and not retried until they change',
    () async {
      final rig = _Rig();
      addTearDown(rig.controller.dispose);
      await rig.ready();
      rig.complete();
      rig.publication.failure = const UnexpectedFailure(
        'places unavailable',
        'invalid_route_place',
      );

      await rig.controller.flush();
      await Future<void>.delayed(_wait);
      expect(rig.publication.sent, hasLength(1));
      expect(rig.controller.state.message, contains('точки больше недоступны'));

      await rig.controller.flush();
      await Future<void>.delayed(_wait);
      expect(
        rig.publication.sent,
        hasLength(1),
        reason: 'blocked until edited',
      );

      // Replacing a point clears the block.
      const other = RouteLocation(
        id: 'p3',
        name: 'Другая',
        subtitle: 'Крым',
        lat: 44.7,
        lng: 34.2,
      );
      rig.publication.failure = null;
      rig.controller.setFinish(other);
      await rig.controller.flush();
      await Future<void>.delayed(_wait);
      expect(rig.publication.sent, hasLength(2));
    },
  );

  test(
    'a photo that reached the server is remembered and not sent again',
    () async {
      final rig = _Rig();
      addTearDown(rig.controller.dispose);
      await rig.ready();
      rig.publication.uploadPhotos = true;
      rig.complete();
      // A photo held on the device (not yet on the server).
      rig.drafts.value = null;
      rig.controller.state = rig.controller.state.copyWith(
        draft: rig.controller.state.draft.copyWith(
          media: const [
            RouteMediaItem(
              id: 'm1',
              path: '/x/a.jpg',
              kind: RouteMediaKind.image,
            ),
          ],
        ),
      );

      await rig.controller.flush();
      await Future<void>.delayed(_wait);
      expect(rig.drafts.value?.media.single.serverMediaId, 'srv-m1');

      rig.controller.setTitle('Маршрут 2');
      await rig.controller.flush();
      await Future<void>.delayed(_wait);
      expect(rig.publication.sent, hasLength(2));
      expect(
        rig.publication.sent.last.media.single.isOnServer,
        isTrue,
        reason: 'the second send knows the photo is already there',
      );
    },
  );

  group('the sync service', () {
    RouteDraft ready(String? owner) => RouteDraft(
      title: 'Маршрут',
      start: _start,
      finish: _finish,
      ownerUserId: owner,
      clientDraftId: 'key-1',
      unsynced: true,
      updatedAt: DateTime.utc(2026, 9, 20),
    );

    test('does not send a draft that belongs to somebody else', () async {
      final rig = _Rig();
      final outcome = await rig.sync.sync('user-1', ready('user-2'));
      expect(outcome, RouteDraftSyncOutcome.notOwner);
      expect(rig.publication.sent, isEmpty);
    });

    test(
      'cancelling stops a running send from touching the stored draft',
      () async {
        final rig = _Rig(stored: ready('user-1'));
        rig.publication.slow = const Duration(milliseconds: 60);

        final running = rig.sync.sync('user-1', ready('user-1'));
        await Future<void>.delayed(const Duration(milliseconds: 15));
        rig.sync.cancel();
        final outcome = await running;

        expect(outcome, RouteDraftSyncOutcome.notOwner);
        expect(rig.drafts.value?.serverId, isNull);
        expect(rig.drafts.value?.unsynced, isTrue);
      },
    );

    test('before sign-out an unsent draft is saved first', () async {
      final rig = _Rig(stored: ready('user-1'));
      expect(await rig.sync.trySendUnsent('user-1'), isTrue);
      expect(rig.publication.sent, hasLength(1));
      expect(rig.drafts.value?.unsynced, isFalse);
    });

    test('before sign-out an unsendable draft is reported', () async {
      final rig = _Rig(stored: ready('user-1'));
      rig.publication.failure = const NetworkFailure();
      expect(await rig.sync.trySendUnsent('user-1'), isFalse);
      expect(rig.drafts.value?.unsynced, isTrue);
    });

    test('a nothing-to-lose draft passes the sign-out check', () async {
      final rig = _Rig();
      expect(await rig.sync.trySendUnsent('user-1'), isTrue);
    });

    test('an interrupted sign-out is finished at the next start', () async {
      final rig = _Rig(stored: ready('user-1'));
      await rig.sync.markSignOutPending();
      await rig.sync.finishInterruptedSignOut();
      expect(rig.drafts.value, isNull);
      expect(rig.store.cleared, isTrue);
    });

    test('a retry with a lost response keeps the same client key', () async {
      final rig = _Rig(stored: ready('user-1'));
      rig.publication.failure = const NetworkFailure();
      await rig.sync.sync('user-1', ready('user-1'));
      rig.publication.failure = null;
      await rig.sync.sync('user-1', ready('user-1'));
      final keys = rig.publication.sent.map((d) => d.clientDraftId).toSet();
      expect(keys, {'key-1'});
    });
  });
}
