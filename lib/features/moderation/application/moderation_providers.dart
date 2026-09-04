import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/features/moderation/data/api_moderation_repository.dart';
import 'package:tourism_mobile/features/moderation/data/mock_moderation_repository.dart';
import 'package:tourism_mobile/features/moderation/domain/content_report.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return MockModerationRepository();
  }
  return ApiModerationRepository(ref.watch(dioProvider));
});
