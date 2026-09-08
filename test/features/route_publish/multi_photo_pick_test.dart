import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_publish/application/route_publish_controller.dart';
import 'package:tourism_mobile/features/route_publish/data/route_draft_media_store.dart';
import 'package:tourism_mobile/features/route_publish/data/route_media_picker.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/domain/route_publish_repository.dart';
import 'package:tourism_mobile/features/routes/data/mock_routes_repository.dart';

/// Adding a gallery one photo at a time — pick, crop, back to the form, pick
/// again — was most of the work of publishing a route.
final class _BatchPicker implements RouteMediaPicker {
  _BatchPicker(this.available);

  final List<String> available;
  int? lastLimit;

  @override
  Future<RouteMediaItem?> pick(RouteMediaSource source) async => null;

  @override
  Future<List<RouteMediaItem>> pickMany(
    RouteMediaSource source, {
    required int limit,
  }) async {
    lastLimit = limit;
    return [
      for (final path in available.take(limit))
        RouteMediaItem(
          id: path,
          path: path,
          kind: RouteMediaKind.image,
        ),
    ];
  }
}

final class _MemoryDrafts implements RouteDraftRepository {
  RouteDraft? value;

  @override
  Future<RouteDraft?> load() async => value;

  @override
  Future<void> save(RouteDraft draft) async => value = draft;

  @override
  Future<void> delete() async => value = null;
}

final class _PassThroughStore implements RouteDraftMediaStore {
  @override
  Future<String> keep(String path) async => '$path.kept';

  @override
  Future<void> purgeExpired() async {}

  @override
  Future<String?> resolve(String path) async => path;
}

final class _StubPublication implements RoutePublicationRepository {
  @override
  Future<RouteDraftPreview> previewRoute({
    required List<String> placeIds,
    String transportMode = 'walk',
  }) async => throw UnimplementedError();

  @override
  Future<RoutePublicationReceipt> saveDraft(RouteDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<RoutePublicationReceipt> submit(RouteDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<RoutePublicationReceipt> withdraw(String routeId) async =>
      throw UnimplementedError();

  @override
  Future<void> discardDraft(String routeId) async {}

  @override
  Future<RouteDraft> loadForEdit(String routeId) async =>
      throw UnimplementedError();
}

RoutePublishController _controller(_BatchPicker picker) {
  return RoutePublishController(
    mode: RoutePublishMode.production,
    drafts: _MemoryDrafts(),
    mediaPicker: picker,
    mediaStore: _PassThroughStore(),
    publication: _StubPublication(),
    routes: MockRoutesRepository(),
  );
}

void main() {
  test('one visit to the gallery adds every photo picked', () async {
    final picker = _BatchPicker(['a.jpg', 'b.jpg', 'c.jpg']);
    final controller = _controller(picker);
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);

    await controller.addMedia(
      RouteMediaSource.galleryImage,
      crop: (paths) async => [for (final path in paths) '$path.cropped'],
    );

    expect(controller.state.draft.media.length, 3);
    // Order survives the crop step, so the first photo picked stays the cover.
    expect(controller.state.draft.media.map((item) => item.path), [
      'a.jpg.cropped.kept',
      'b.jpg.cropped.kept',
      'c.jpg.cropped.kept',
    ]);
  });

  test('the picker is only offered the room that is left', () async {
    final picker = _BatchPicker(List.generate(12, (i) => 'p$i.jpg'));
    final controller = _controller(picker);
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);

    await controller.addMedia(RouteMediaSource.galleryImage);
    expect(picker.lastLimit, RoutePublishController.maxMedia);
    expect(
      controller.state.draft.media.length,
      RoutePublishController.maxMedia,
    );

    // Full: nothing more is picked, and the author is told why.
    picker.lastLimit = null;
    await controller.addMedia(RouteMediaSource.galleryImage);
    expect(picker.lastLimit, isNull);
    expect(
      controller.state.draft.media.length,
      RoutePublishController.maxMedia,
    );
  });

  test('backing out of the editor adds nothing', () async {
    final picker = _BatchPicker(['a.jpg', 'b.jpg']);
    final controller = _controller(picker);
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);

    await controller.addMedia(
      RouteMediaSource.galleryImage,
      crop: (paths) async => null,
    );

    expect(controller.state.draft.media, isEmpty);
  });

  test('a photo the editor could not read is skipped, not fatal', () async {
    final picker = _BatchPicker(['a.jpg', 'broken.jpg', 'c.jpg']);
    final controller = _controller(picker);
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);

    // The editor hands back fewer files than it was given.
    await controller.addMedia(
      RouteMediaSource.galleryImage,
      crop: (paths) async => ['a.jpg.cropped', 'c.jpg.cropped'],
    );

    expect(controller.state.draft.media.length, 2);
  });
}
