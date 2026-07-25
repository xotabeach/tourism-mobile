import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/places/domain/places_repository.dart';

class ApiPlacesRepository implements PlacesRepository {
  ApiPlacesRepository(this._dio);

  final Dio _dio;

  @override
  Future<PlaceListPage> listPlaces({
    String? regionSlug,
    String? category,
    String? query,
  }) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/places',
        queryParameters: {
          'region_slug': ?regionSlug,
          'category': ?category,
          if (query != null && query.isNotEmpty) 'q': query,
          'limit': 50,
        },
      );
      return PlaceListPage.fromJson(response.data!);
    });
  }

  @override
  Future<PlaceDetail> getPlace(String id) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/places/$id',
      );
      return PlaceDetail.fromJson(response.data!);
    });
  }
}
