import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/cache/api_cache.dart';

void main() {
  group('ApiCache', () {
    test('returns null on cache miss', () {
      final cache = ApiCache<String, int>();
      expect(cache.get('a'), isNull);
    });

    test('returns value on cache hit', () {
      final cache = ApiCache<String, int>();
      cache.set('a', 42);
      expect(cache.get('a'), 42);
    });

    test('evicts expired entries', () async {
      final cache = ApiCache<String, int>(
        ttl: const Duration(milliseconds: 50),
      );
      cache.set('a', 1);
      expect(cache.get('a'), 1);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(cache.get('a'), isNull);
    });

    test('invalidate single key', () {
      final cache = ApiCache<String, int>();
      cache.set('a', 1);
      cache.set('b', 2);
      cache.invalidate('a');
      expect(cache.get('a'), isNull);
      expect(cache.get('b'), 2);
    });

    test('invalidate all', () {
      final cache = ApiCache<String, int>();
      cache.set('a', 1);
      cache.set('b', 2);
      cache.invalidate();
      expect(cache.get('a'), isNull);
      expect(cache.get('b'), isNull);
      expect(cache.length, 0);
    });
  });

  group('ApiCacheRegistry', () {
    test('invalidateAll clears all registered caches', () {
      final registry = ApiCacheRegistry();
      final c1 = ApiCache<String, int>();
      final c2 = ApiCache<String, String>();
      registry.register(c1);
      registry.register(c2);
      c1.set('x', 1);
      c2.set('y', 'hello');
      registry.invalidateAll();
      expect(c1.get('x'), isNull);
      expect(c2.get('y'), isNull);
    });
  });
}
