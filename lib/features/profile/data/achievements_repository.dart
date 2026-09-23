import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';

final achievementsRepositoryProvider = Provider<AchievementsRepository>((ref) {
  return AchievementsRepository(
    ref.watch(dioProvider),
    mock: ref.watch(appConfigProvider).useMockData,
  );
});

class AchievementsRepository {
  AchievementsRepository(this._dio, {this.mock = false});
  final Dio _dio;
  final bool mock;

  Future<List<ProfileAchievement>> list({bool uncelebrated = false}) async {
    if (mock) return [];
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/me/achievements',
        queryParameters: {if (uncelebrated) 'uncelebrated': true},
      );
      final items = response.data?['items'] as List<dynamic>? ?? [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(ProfileAchievement.fromJson)
          .toList();
    });
  }

  Future<void> celebrate(List<String> ids) async {
    if (mock || ids.isEmpty) return;
    await guardApiCall(
      () => _dio.post<void>(
        '/api/v1/me/achievements/celebrated',
        data: {'achievement_ids': ids},
      ),
    );
  }
}
