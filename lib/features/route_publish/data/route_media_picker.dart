import 'package:image_picker/image_picker.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';

enum RouteMediaSource { galleryImage, cameraImage, galleryVideo, cameraVideo }

abstract interface class RouteMediaPicker {
  /// One file, for the camera and for video.
  Future<RouteMediaItem?> pick(RouteMediaSource source);

  /// Every photo the author selected in one visit to the gallery.
  ///
  /// Adding a gallery one photo at a time — pick, crop, back to the form,
  /// pick again — is most of the work of publishing a route. Sources that
  /// cannot select more than one (the camera, video) return a single-item
  /// list, so call sites do not have to branch.
  Future<List<RouteMediaItem>> pickMany(
    RouteMediaSource source, {
    required int limit,
  });
}

final class ImagePickerRouteMediaPicker implements RouteMediaPicker {
  ImagePickerRouteMediaPicker(this._picker);

  final ImagePicker _picker;

  @override
  Future<RouteMediaItem?> pick(RouteMediaSource source) async {
    final XFile? file;
    final RouteMediaKind kind;
    switch (source) {
      case RouteMediaSource.galleryImage:
        kind = RouteMediaKind.image;
        file = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 4096,
          maxHeight: 4096,
          imageQuality: 90,
        );
      case RouteMediaSource.cameraImage:
        kind = RouteMediaKind.image;
        file = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 4096,
          maxHeight: 4096,
          imageQuality: 90,
        );
      case RouteMediaSource.galleryVideo:
        kind = RouteMediaKind.video;
        file = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 3),
        );
      case RouteMediaSource.cameraVideo:
        kind = RouteMediaKind.video;
        file = await _picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 3),
        );
    }
    if (file == null) {
      return null;
    }
    return _validated(file, kind);
  }

  @override
  Future<List<RouteMediaItem>> pickMany(
    RouteMediaSource source, {
    required int limit,
  }) async {
    if (limit <= 0) {
      return const [];
    }
    if (source != RouteMediaSource.galleryImage) {
      // The camera takes one shot, and multi-select for video is not offered.
      final single = await pick(source);
      return single == null ? const [] : [single];
    }
    final files = await _picker.pickMultiImage(
      limit: limit,
      maxWidth: 4096,
      maxHeight: 4096,
      imageQuality: 90,
    );
    final items = <RouteMediaItem>[];
    for (final file in files.take(limit)) {
      items.add(await _validated(file, RouteMediaKind.image));
    }
    return items;
  }

  Future<RouteMediaItem> _validated(XFile file, RouteMediaKind kind) async {
    final bytes = await file.length();
    if (bytes > 100 * 1024 * 1024) {
      throw const FormatException('Файл больше допустимых 100 МБ');
    }
    final normalized = file.path.toLowerCase();
    final allowed = kind == RouteMediaKind.image
        ? const ['.jpg', '.jpeg', '.png', '.heic', '.webp']
        : const ['.mp4', '.mov', '.m4v'];
    if (!allowed.any(normalized.endsWith)) {
      throw const FormatException('Этот формат файла не поддерживается');
    }
    return RouteMediaItem(
      id: '${DateTime.now().microsecondsSinceEpoch}-${file.name}',
      path: file.path,
      kind: kind,
    );
  }
}
