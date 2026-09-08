import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:tourism_mobile/features/route_publish/data/route_draft_media_store.dart';

/// Points path_provider at a scratch directory so the store can be exercised
/// without a device.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('draft-media-test');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  Future<File> sourcePhoto(String name) async {
    // Where the picker and the cropper actually leave their files: a temp
    // directory the OS is free to clear.
    final temp = await Directory.systemTemp.createTemp('picked');
    final file = File('${temp.path}/$name');
    await file.writeAsBytes([1, 2, 3], flush: true);
    return file;
  }

  test('a kept photo survives losing the picker\'s own file', () async {
    final store = AppDirRouteDraftMediaStore();
    final picked = await sourcePhoto('photo.jpg');

    final kept = await store.keep(picked.path);
    expect(kept, isNot(picked.path));
    expect(await File(kept).exists(), isTrue);

    // The OS clears the temp directory; the draft's copy must not care.
    await picked.parent.delete(recursive: true);
    expect(await File(kept).exists(), isTrue);
    expect(await store.existing([kept]), [kept]);
  });

  test('a photo that vanished is reported as gone, not silently kept', () async {
    final store = AppDirRouteDraftMediaStore();
    final kept = await store.keep((await sourcePhoto('a.jpg')).path);
    await File(kept).delete();

    expect(await store.existing([kept]), isEmpty);
  });

  test('copies outlive a week of editing but not an abandoned draft', () async {
    final store = AppDirRouteDraftMediaStore();
    final fresh = await store.keep((await sourcePhoto('fresh.jpg')).path);
    final stale = await store.keep((await sourcePhoto('stale.jpg')).path);

    // Backdate one past the retention window.
    await File(stale).setLastModified(
      DateTime.now().subtract(const Duration(days: 8)),
    );
    await store.purgeExpired();

    expect(await File(fresh).exists(), isTrue, reason: 'inside the week');
    expect(await File(stale).exists(), isFalse, reason: 'past the week');
  });

  test('an unreadable source leaves the original path rather than losing it', () async {
    final store = AppDirRouteDraftMediaStore();
    const missing = '/nowhere/does-not-exist.jpg';
    expect(await store.keep(missing), missing);
  });
}
