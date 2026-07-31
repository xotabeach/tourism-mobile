import 'package:tourism_mobile/core/cache/api_cache.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/places/domain/places_repository.dart';

class CachingPlacesRepository implements PlacesRepository {
  CachingPlacesRepository(this._inner, {required ApiCacheRegistry registry})
    : _listCache = ApiCache<String, PlaceListPage>(
        ttl: const Duration(minutes: 5),
      ),
      _detailCache = ApiCache<String, PlaceDetail>(
        ttl: const Duration(minutes: 10),
      ) {
    registry.register(_listCache);
    registry.register(_detailCache);
  }

  final PlacesRepository _inner;
  final ApiCache<String, PlaceListPage> _listCache;
  final ApiCache<String, PlaceDetail> _detailCache;

  @override
  Future<PlaceListPage> listPlaces({
    String? regionSlug,
    String? category,
    String? query,
  }) async {
    final key = '${regionSlug ?? ''}|${category ?? ''}|${query ?? ''}';
    final cached = _listCache.get(key);
    if (cached != null) return cached;
    final result = await _inner.listPlaces(
      regionSlug: regionSlug,
      category: category,
      query: query,
    );
    _listCache.set(key, result);
    return result;
  }

  @override
  Future<PlaceDetail> getPlace(String id) async {
    final cached = _detailCache.get(id);
    if (cached != null) return cached;
    final result = await _inner.getPlace(id);
    _detailCache.set(id, result);
    return result;
  }
}
