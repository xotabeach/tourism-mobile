import 'package:tourism_mobile/core/cache/api_cache.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/domain/routes_repository.dart';

class CachingRoutesRepository implements RoutesRepository {
  CachingRoutesRepository(this._inner, {required ApiCacheRegistry registry})
    : _listCache = ApiCache<String, RouteListPage>(
        ttl: const Duration(minutes: 5),
      ),
      _detailCache = ApiCache<String, RouteDetail>(
        ttl: const Duration(minutes: 10),
      ) {
    registry.register(_listCache);
    registry.register(_detailCache);
  }

  final RoutesRepository _inner;
  final ApiCache<String, RouteListPage> _listCache;
  final ApiCache<String, RouteDetail> _detailCache;

  @override
  Future<RouteListPage> listRoutes({String? regionSlug}) async {
    final key = regionSlug ?? '';
    final cached = _listCache.get(key);
    if (cached != null) return cached;
    final result = await _inner.listRoutes(regionSlug: regionSlug);
    _listCache.set(key, result);
    return result;
  }

  @override
  Future<RouteDetail> getRoute(String id) async {
    final cached = _detailCache.get(id);
    if (cached != null) return cached;
    final result = await _inner.getRoute(id);
    _detailCache.set(id, result);
    return result;
  }
}
