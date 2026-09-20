import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// `X-App-Version: 0.2.6+12` and `X-App-Platform: android`, so the server can
/// tell which app versions are still in use. Both are optional for the server.
typedef AppVersionHeadersLoader = Future<Map<String, String>> Function();

Map<String, String>? _cached;

Future<Map<String, String>> loadAppVersionHeaders() async {
  final cached = _cached;
  if (cached != null) {
    return cached;
  }
  try {
    final info = await PackageInfo.fromPlatform();
    final headers = <String, String>{
      if (info.version.isNotEmpty && info.buildNumber.isNotEmpty)
        'X-App-Version': '${info.version}+${info.buildNumber}',
      'X-App-Platform': switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        _ => 'other',
      },
    };
    return _cached = headers;
  } on Object {
    return const {};
  }
}

// Explicit type: a bare top-level provider here would form an inference cycle
// with the Dio providers that read it.
final Provider<AppVersionHeadersLoader> appVersionHeadersLoaderProvider =
    Provider<AppVersionHeadersLoader>((ref) => loadAppVersionHeaders);

Interceptor appVersionInterceptor(AppVersionHeadersLoader load) {
  return InterceptorsWrapper(
    onRequest: (options, handler) async {
      options.headers.addAll(await load());
      handler.next(options);
    },
  );
}
