import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/moderation/domain/content_report.dart';

final class ApiModerationRepository implements ModerationRepository {
  ApiModerationRepository(this._dio);

  final Dio _dio;

  @override
  Future<ContentReport> report({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? comment,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/reports',
        data: {
          'target_type': targetType.apiValue,
          'target_id': targetId,
          'reason': reason.apiValue,
          'comment': ?comment,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return ContentReport.fromJson(data);
    });
  }
}
