import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/settings/domain/company_details.dart';
import 'package:tourism_mobile/features/settings/domain/company_details_repository.dart';

final class ApiCompanyDetailsRepository implements CompanyDetailsRepository {
  ApiCompanyDetailsRepository(this._dio);

  final Dio _dio;

  @override
  Future<CompanyDetails> fetch() {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/company-details',
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return CompanyDetails.fromJson(data);
    });
  }
}
