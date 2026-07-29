import 'package:flutter_riverpod/flutter_riverpod.dart';

class _CacheEntry<V> {
  _CacheEntry(this.value, this.expiresAt);
  final V value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Generic in-memory TTL cache.
///
/// Keys must implement [==] and [hashCode] (String, record tuples, etc.).
class ApiCache<K, V> {
  ApiCache({this.ttl = const Duration(minutes: 5)});

  final Duration ttl;
  final _entries = <K, _CacheEntry<V>>{};

  V? get(K key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _entries.remove(key);
      return null;
    }
    return entry.value;
  }

  void set(K key, V value) {
    _entries[key] = _CacheEntry(value, DateTime.now().add(ttl));
  }

  void invalidate([K? key]) {
    if (key != null) {
      _entries.remove(key);
    } else {
      _entries.clear();
    }
  }

  int get length => _entries.length;
}

/// Holds references to all API caches so they can be cleared globally.
class ApiCacheRegistry {
  final _caches = <ApiCache<dynamic, dynamic>>[];

  void register(ApiCache<dynamic, dynamic> cache) {
    _caches.add(cache);
  }

  void invalidateAll() {
    for (final cache in _caches) {
      cache.invalidate();
    }
  }
}

final apiCacheRegistryProvider = Provider<ApiCacheRegistry>((ref) {
  return ApiCacheRegistry();
});
