import 'package:image_picker/image_picker.dart';

/// A file picked for an article image block, before it is uploaded via
/// `ArticlesRepository.uploadBlockImage` (see G.9 — upload is a separate
/// step from the block-list PATCH so a flaky connection only needs the
/// upload retried).
class PickedArticleImage {
  const PickedArticleImage({required this.path, required this.name});

  final String path;
  final String name;
}

abstract interface class ArticleImagePicker {
  Future<PickedArticleImage?> pickFromGallery();
}

final class ImagePickerArticleImagePicker implements ArticleImagePicker {
  ImagePickerArticleImagePicker(this._picker);

  final ImagePicker _picker;

  static const _allowedExtensions = ['.jpg', '.jpeg', '.png', '.heic', '.webp'];
  static const _maxBytes = 20 * 1024 * 1024;

  @override
  Future<PickedArticleImage?> pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 4096,
      maxHeight: 4096,
      imageQuality: 90,
    );
    if (file == null) {
      return null;
    }
    final bytes = await file.length();
    if (bytes > _maxBytes) {
      throw const FormatException('Файл больше допустимых 20 МБ');
    }
    final normalized = file.path.toLowerCase();
    if (!_allowedExtensions.any(normalized.endsWith)) {
      throw const FormatException('Этот формат изображения не поддерживается');
    }
    return PickedArticleImage(path: file.path, name: file.name);
  }
}
