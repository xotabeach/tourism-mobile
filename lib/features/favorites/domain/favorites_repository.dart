abstract interface class FavoritesRepository {
  Future<({Set<String> placeIds, Set<String> routeIds})> list();

  Future<void> addRoute(String routeId);

  Future<void> removeRoute(String routeId);

  Future<void> addPlace(String placeId);

  Future<void> removePlace(String placeId);
}
