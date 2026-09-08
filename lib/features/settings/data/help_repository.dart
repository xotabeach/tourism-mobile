import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';

class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.revision,
    required this.appVersion,
    required this.title,
    required this.excerpt,
    this.body,
  });

  final String id;
  final int revision;
  final String appVersion;
  final String title;
  final String excerpt;
  final String? body;

  factory HelpArticle.fromJson(Map<String, dynamic> json) => HelpArticle(
    id: json['article_id'] as String,
    revision: json['revision'] as int,
    appVersion: json['app_version'] as String,
    title: json['title'] as String,
    excerpt: json['excerpt'] as String,
    body: json['body'] as String?,
  );
}

class HelpSearchResult {
  const HelpSearchResult({required this.available, required this.articles});

  final bool available;
  final List<HelpArticle> articles;
}

abstract interface class HelpRepository {
  Future<HelpSearchResult> search(String query);
  Future<HelpArticle> read(HelpArticle article);
}

class ApiHelpRepository implements HelpRepository {
  ApiHelpRepository(this._dio, this._version);

  final Dio _dio;
  final Future<String> Function() _version;

  @override
  Future<HelpSearchResult> search(String query) => guardApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/support/help/search',
      data: {'q': query, 'app_version': await _version()},
    );
    final data = response.data!;
    return HelpSearchResult(
      available: data['available'] as bool,
      articles: [
        for (final item in data['items'] as List<dynamic>)
          HelpArticle.fromJson(item as Map<String, dynamic>),
      ],
    );
  });

  @override
  Future<HelpArticle> read(HelpArticle article) => guardApiCall(() async {
    // Fetch again: a search result is not permission to read a withdrawn edition.
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/support/help/${Uri.encodeComponent(article.id)}',
      queryParameters: {
        'revision': article.revision,
        'app_version': article.appVersion,
      },
    );
    final loaded = HelpArticle.fromJson(response.data!);
    if (loaded.id != article.id ||
        loaded.revision != article.revision ||
        loaded.appVersion != article.appVersion ||
        loaded.body == null ||
        loaded.body!.trim().isEmpty) {
      throw const UnexpectedFailure();
    }
    return loaded;
  });
}

final helpRepositoryProvider = Provider<HelpRepository>((ref) {
  return ApiHelpRepository(
    ref.watch(dioProvider),
    () async => (await PackageInfo.fromPlatform()).version,
  );
});
