import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';

/// «Легче / Как ожидал / Сложнее» after a run (spec 17, section 7).
enum DifficultyFeedback {
  easier('easier', 'Легче'),
  asExpected('as_expected', 'Как ожидал'),
  harder('harder', 'Сложнее');

  const DifficultyFeedback(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Sends the answer; null in mock mode, where there is no server.
typedef SendDifficultyFeedback =
    Future<void> Function(String executionId, DifficultyFeedback answer);

final sendDifficultyFeedbackProvider = Provider<SendDifficultyFeedback>((ref) {
  if (ref.watch(appConfigProvider).useMockData) {
    return (_, _) async {};
  }
  final Dio dio = ref.watch(dioProvider);
  return (executionId, answer) async {
    await dio.post<void>(
      '/api/v1/route-executions/$executionId/difficulty-feedback',
      data: {'answer': answer.apiValue},
    );
  };
});
