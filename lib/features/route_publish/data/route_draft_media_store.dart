import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Durable home for photos attached to a draft that has not been published.
///
/// Both sources hand back files the OS may delete underneath us: the picker
/// copies into a cache directory, and the cropper writes into
/// [Directory.systemTemp]. A draft saved with those paths still listed its
/// photos after a restart, but every file behind them was gone — reported
/// 2026-09-08 as "черновик открылся, а фото в нём нет".
///
/// Copies live under the app's support directory, which is backed up and not
/// swept by the system, and are pruned by age so an abandoned draft cannot
/// keep megabytes forever.
abstract interface class RouteDraftMediaStore {
  /// Copies [path] into durable storage and returns the new path. Returns
  /// [path] unchanged when the copy fails — a draft that keeps a fragile
  /// path is still better than losing the photo the author just picked.
  Future<String> keep(String path);

  /// Deletes copies older than the retention window.
  Future<void> purgeExpired();

  /// Paths that still resolve to a file, in the order given.
  Future<List<String>> existing(List<String> paths);
}

final class AppDirRouteDraftMediaStore implements RouteDraftMediaStore {
  AppDirRouteDraftMediaStore({Duration? retention})
    : retention = retention ?? const Duration(days: 7);

  /// How long an unpublished draft keeps its photos. Long enough to come
  /// back to the draft after a few days, short enough that abandoned drafts
  /// do not accumulate.
  final Duration retention;

  static const _folder = 'route_draft_media';

  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/$_folder');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  @override
  Future<String> keep(String path) async {
    try {
      final source = File(path);
      if (!await source.exists()) {
        return path;
      }
      final directory = await _directory();
      final name = path.split('/').last;
      final target = File(
        '${directory.path}/${DateTime.now().microsecondsSinceEpoch}-$name',
      );
      // Copy rather than move: the picker owns its file and may still be
      // reading it, and on Android the source can sit on another volume.
      await source.copy(target.path);
      return target.path;
    } on Object {
      return path;
    }
  }

  @override
  Future<void> purgeExpired() async {
    try {
      final directory = await _directory();
      final cutoff = DateTime.now().subtract(retention);
      await for (final entity in directory.list()) {
        if (entity is! File) {
          continue;
        }
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
        }
      }
    } on Object {
      // Housekeeping only — never block opening a draft on it.
    }
  }

  @override
  Future<List<String>> existing(List<String> paths) async {
    final kept = <String>[];
    for (final path in paths) {
      try {
        if (await File(path).exists()) {
          kept.add(path);
        }
      } on Object {
        // Unreadable counts as gone.
      }
    }
    return kept;
  }
}
