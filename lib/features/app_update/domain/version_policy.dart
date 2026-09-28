/// What the server says about this build (BACKEND-5).
enum UpdateKind { none, soft, hard }

class VersionPolicy {
  const VersionPolicy({
    required this.kind,
    this.latestVersion,
    this.hardAt,
    this.downloadUrl,
    this.storeUrl,
    this.message = defaultMessage,
  });

  static const none = VersionPolicy(kind: UpdateKind.none);

  static const defaultMessage =
      'Вышла новая версия КрымТрипа. Обновите приложение, чтобы пользоваться '
      'новыми функциями и исправлениями.';

  final UpdateKind kind;
  final String? latestVersion;

  /// When a soft prompt turns into a block.
  final DateTime? hardAt;
  final String? downloadUrl;
  final String? storeUrl;
  final String message;

  /// Store first, once there is one; until then the APK on the landing.
  Uri? get updateUri {
    for (final raw in [storeUrl, downloadUrl]) {
      final uri = raw == null ? null : Uri.tryParse(raw);
      if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
        return uri;
      }
    }
    return null;
  }

  /// Anything unexpected reads as «no update»: a bad answer must never block.
  factory VersionPolicy.fromJson(Map<String, dynamic> json) {
    final kind = switch (json['update_kind']) {
      'soft' => UpdateKind.soft,
      'hard' => UpdateKind.hard,
      _ => UpdateKind.none,
    };
    final message = json['message'];
    final hardAt = json['hard_at'];
    final policy = VersionPolicy(
      kind: kind,
      latestVersion: json['latest_version'] as String?,
      hardAt: hardAt is String ? DateTime.tryParse(hardAt) : null,
      downloadUrl: json['download_url'] as String?,
      storeUrl: json['store_url'] as String?,
      message: message is String && message.trim().isNotEmpty
          ? message.trim()
          : defaultMessage,
    );
    // Nowhere to send the person: telling them to update would be a dead end.
    return policy.updateUri == null ? none : policy;
  }
}
