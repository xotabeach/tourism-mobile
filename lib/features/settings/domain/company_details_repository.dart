import 'package:tourism_mobile/features/settings/domain/company_details.dart';

abstract interface class CompanyDetailsRepository {
  Future<CompanyDetails> fetch();
}
