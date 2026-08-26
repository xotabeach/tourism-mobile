import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/features/settings/data/preferences_repository.dart';

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return MockPreferencesRepository();
  }
  return ApiPreferencesRepository(ref.watch(dioProvider));
});

final travelPreferencesProvider = FutureProvider.autoDispose<TravelPreferences>(
  (ref) {
    return ref.watch(preferencesRepositoryProvider).getPreferences();
  },
);
