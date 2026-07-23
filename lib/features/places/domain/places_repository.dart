import 'package:tourism_mobile/features/places/domain/place.dart';

abstract class PlacesRepository {
  Future<PlaceListPage> listPlaces({
    String? regionSlug,
    String? category,
    String? query,
  });

  Future<PlaceDetail> getPlace(String id);
}
