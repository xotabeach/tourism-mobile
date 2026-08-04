import 'package:image_picker/image_picker.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';

enum RouteMediaSource { galleryImage, cameraImage, galleryVideo, cameraVideo }

abstract interface class RouteMediaPicker {
  Future<RouteMediaItem?> pick(RouteMediaSource source);
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
