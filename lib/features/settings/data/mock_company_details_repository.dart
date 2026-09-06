import 'package:tourism_mobile/features/settings/domain/company_details.dart';
import 'package:tourism_mobile/features/settings/domain/company_details_repository.dart';

/// Filled-in sample so the "О приложении" preview looks complete in
/// `DATA_SOURCE=mock` builds, instead of showing "Уточняется" everywhere.
final class MockCompanyDetailsRepository implements CompanyDetailsRepository {
  @override
  Future<CompanyDetails> fetch() async {
    return const CompanyDetails(
      legalName: 'ИП Иванов Иван Иванович',
      brandName: 'КрымТрип',
      inn: '910123456789',
      ogrn: '318910200000000',
      address: 'Республика Крым, г. Симферополь',
      email: 'hello@crimeatrip.app',
      phone: '+7 900 000-00-00',
      telegram: '@crimeatrip_support',
      workingHours: 'Ежедневно с 10:00 до 20:00 (МСК)',
    );
  }
}
