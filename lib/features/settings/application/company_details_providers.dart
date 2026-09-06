import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/features/settings/data/api_company_details_repository.dart';
import 'package:tourism_mobile/features/settings/data/company_details_cache.dart';
import 'package:tourism_mobile/features/settings/data/mock_company_details_repository.dart';
import 'package:tourism_mobile/features/settings/domain/company_details.dart';
import 'package:tourism_mobile/features/settings/domain/company_details_repository.dart';

final companyDetailsRepositoryProvider = Provider<CompanyDetailsRepository>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return MockCompanyDetailsRepository();
  }
  return ApiCompanyDetailsRepository(ref.watch(dioProvider));
});

final companyDetailsCacheProvider = Provider<CompanyDetailsCache>((ref) {
  return SharedPreferencesCompanyDetailsCache();
});

/// Реквизиты и контакты для «О приложении» — админ-редактируемые, читаются
/// с бекенда и кешируются на диске, чтобы офлайн показывал последнее
/// известное значение, а не выдумки.
final companyDetailsProvider = FutureProvider.autoDispose<CompanyDetails>((
  ref,
) async {
  final cache = ref.watch(companyDetailsCacheProvider);
  try {
    final details = await ref.watch(companyDetailsRepositoryProvider).fetch();
    unawaited(cache.save(details));
    return details;
  } on Object {
    final cached = await cache.read();
    if (cached != null) {
      return cached;
    }
    return const CompanyDetails();
  }
});
