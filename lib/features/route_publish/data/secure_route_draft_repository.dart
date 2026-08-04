import 'dart:convert';

import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/domain/route_publish_repository.dart';

final class SecureRouteDraftRepository implements RouteDraftRepository {
  SecureRouteDraftRepository(this._storage);

  static const _key = 'routes.publish_draft.v1';
  final SecureStoragePort _storage;

  @override
  Future<RouteDraft?> load() async {
    final encoded = await _storage.read(key: _key);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      return RouteDraft.fromJson(
        Map<String, Object?>.from(jsonDecode(encoded) as Map),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(RouteDraft draft) {
    return _storage.write(key: _key, value: jsonEncode(draft.toJson()));
  }
}
