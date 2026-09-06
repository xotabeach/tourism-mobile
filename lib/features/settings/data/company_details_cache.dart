import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourism_mobile/features/settings/domain/company_details.dart';

abstract interface class CompanyDetailsCache {
  Future<CompanyDetails?> read();

  Future<void> save(CompanyDetails details);
}

/// Small, versioned JSON store — same convention as
/// SharedPreferencesSessionIdentityCache. Lets the "О приложении" screen
/// show the last-fetched company details instead of hardcoded defaults when the
/// device is offline.
final class SharedPreferencesCompanyDetailsCache
    implements CompanyDetailsCache {
  SharedPreferencesCompanyDetailsCache({
    Future<SharedPreferences> Function()? loader,
  }) : _loader = loader ?? SharedPreferences.getInstance;

  static const _key = 'crimeatrip.settings.cached_company_details';
  static const _version = 1;

  final Future<SharedPreferences> Function() _loader;
  Future<SharedPreferences>? _prefsFuture;

  Future<SharedPreferences> get _prefs async => _prefsFuture ??= _loader();

  @override
  Future<CompanyDetails?> read() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key);
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['version'] != _version) {
        return null;
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return null;
      }
      return CompanyDetails.fromJson(data);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(CompanyDetails details) async {
    final prefs = await _prefs;
    await prefs.setString(
      _key,
      jsonEncode({'version': _version, 'data': details.toJson()}),
    );
  }
}

final class MemoryCompanyDetailsCache implements CompanyDetailsCache {
  CompanyDetails? _details;

  @override
  Future<CompanyDetails?> read() async => _details;

  @override
  Future<void> save(CompanyDetails details) async {
    _details = details;
  }
}
