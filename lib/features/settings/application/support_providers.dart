import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/features/settings/data/support_repository.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return MockSupportRepository();
  }
  return ApiSupportRepository(ref.watch(dioProvider));
});
