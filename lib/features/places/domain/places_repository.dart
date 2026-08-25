import 'package:tourism_mobile/features/places/domain/place.dart';

abstract class PlacesRepository {
  Future<PlaceListPage> listPlaces({
    String? regionSlug,
    String? category,
    String? query,
    int limit = 50,
    int offset = 0,
  });

  Future<PlaceDetail> getPlace(String id);
}
