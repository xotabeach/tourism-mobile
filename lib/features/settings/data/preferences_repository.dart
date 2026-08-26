import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';

/// Same taxonomy as `routeCatalogFilters` (routes/application/route_catalog_filter.dart)
/// — the quiz answers feed the same category labels the catalog already
/// filters on.
const preferenceCategories = ['Море', 'Горы', 'Еда', 'Лес'];

class TravelPreferences {
  const TravelPreferences({
    this.categories = const [],
    this.difficulty,
    this.travelsWithKids = false,
    this.travelsWithPets = false,
    this.updatedAt,
  });

  final List<String> categories;
  final String? difficulty;
  final bool travelsWithKids;
  final bool travelsWithPets;
  final DateTime? updatedAt;

  bool get isCompleted => updatedAt != null;

  factory TravelPreferences.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['preferred_categories'];
    final rawUpdatedAt = json['preferences_updated_at'] as String?;
    return TravelPreferences(
      categories: rawCategories is List
          ? [for (final item in rawCategories) item as String]
          : const [],
      difficulty: json['preferred_difficulty'] as String?,
      travelsWithKids: json['travels_with_kids'] as bool? ?? false,
      travelsWithPets: json['travels_with_pets'] as bool? ?? false,
      updatedAt: rawUpdatedAt == null
          ? null
          : DateTime.tryParse(rawUpdatedAt)?.toLocal(),
    );
  }
}

abstract interface class PreferencesRepository {
  Future<TravelPreferences> getPreferences();

  Future<TravelPreferences> updatePreferences({
    required List<String> categories,
    required String? difficulty,
    required bool travelsWithKids,
    required bool travelsWithPets,
  });
}

final class ApiPreferencesRepository implements PreferencesRepository {
  ApiPreferencesRepository(this._dio);

  final Dio _dio;

  @override
  Future<TravelPreferences> getPreferences() {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>('/api/v1/me');
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return TravelPreferences.fromJson(data);
    });
  }

  @override
  Future<TravelPreferences> updatePreferences({
    required List<String> categories,
    required String? difficulty,
    required bool travelsWithKids,
    required bool travelsWithPets,
  }) {
    return guardApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/me/preferences',
        data: {
          'preferred_categories': categories,
          'preferred_difficulty': difficulty,
          'travels_with_kids': travelsWithKids,
          'travels_with_pets': travelsWithPets,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return TravelPreferences.fromJson(data);
    });
  }
}

final class MockPreferencesRepository implements PreferencesRepository {
  TravelPreferences _current = const TravelPreferences();

  @override
  Future<TravelPreferences> getPreferences() async => _current;

  @override
  Future<TravelPreferences> updatePreferences({
    required List<String> categories,
    required String? difficulty,
    required bool travelsWithKids,
    required bool travelsWithPets,
  }) async {
    _current = TravelPreferences(
      categories: categories,
      difficulty: difficulty,
      travelsWithKids: travelsWithKids,
      travelsWithPets: travelsWithPets,
      updatedAt: DateTime.now().toUtc(),
    );
    return _current;
  }
}
