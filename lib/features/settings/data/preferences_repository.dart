import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';

/// Interest words of the profile quiz (design, FRONTEND-21). The backend maps
/// each to place categories for recommendations and the route matcher, and
/// folds older words (Море, Горы, Еда, Лес, chat interests) into these.
const preferenceCategories = [
  'Природа',
  'Гастрономия',
  'История',
  'Смотровые',
  'Романтика',
  'Семейное',
];

/// «Длительность маршрута»: the same keys the route-match form uses.
const preferenceDurations = [
  ('d1_2', '1-2 дня'),
  ('d3_5', '3-5 дней'),
  ('d6_7', '6-7 дней'),
  ('d7plus', '>7 дней'),
];

/// «На транспорте» is stored apart from the difficulty (it is a way to
/// travel, not a level), but offered in the same single choice.
const preferenceTransportCar = 'car';

class TravelPreferences {
  const TravelPreferences({
    this.categories = const [],
    this.difficulty,
    this.duration,
    this.transport,
    this.travelsWithKids = false,
    this.travelsWithPets = false,
    this.updatedAt,
  });

  final List<String> categories;
  final String? difficulty;
  final String? duration;
  final String? transport;
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
      duration: json['preferred_duration'] as String?,
      transport: json['preferred_transport'] as String?,
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
    String? duration,
    String? transport,
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
    String? duration,
    String? transport,
  }) {
    return guardApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/me/preferences',
        data: {
          'preferred_categories': categories,
          'preferred_difficulty': difficulty,
          'preferred_duration': duration,
          'preferred_transport': transport,
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
    String? duration,
    String? transport,
  }) async {
    _current = TravelPreferences(
      categories: categories,
      difficulty: difficulty,
      duration: duration,
      transport: transport,
      travelsWithKids: travelsWithKids,
      travelsWithPets: travelsWithPets,
      updatedAt: DateTime.now().toUtc(),
    );
    return _current;
  }
}
