/// Жалоба на пользовательский контент.
///
/// Один тип на все объекты: пожаловаться можно на комментарий, статью,
/// маршрут или место — сервер держит одну очередь модерации, и клиенту
/// незачем размножать сущности.
enum ReportTargetType {
  articleComment('article_comment'),
  article('article'),
  route('route'),
  place('place');

  const ReportTargetType(this.apiValue);

  final String apiValue;
}

/// Причины — это то, что человек выбирает списком. Формулировки короткие:
/// длинный список читается дольше, чем пишется сама жалоба.
enum ReportReason {
  spam('spam', 'Спам или реклама'),
  abuse('abuse', 'Оскорбления или травля'),
  inappropriate('inappropriate', 'Неприемлемое содержимое'),
  misinformation('misinformation', 'Недостоверные сведения'),
  copyright('copyright', 'Чужие материалы'),
  other('other', 'Другое');

  const ReportReason(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class ContentReport {
  const ContentReport({
    required this.id,
    required this.reason,
    required this.status,
    required this.alreadyReported,
  });

  final String id;
  final String reason;
  final String status;

  /// Жалоба на этот объект от этого человека уже была — сервер вернул её же.
  final bool alreadyReported;

  factory ContentReport.fromJson(Map<String, Object?> json) {
    return ContentReport(
      id: json['id']! as String,
      reason: json['reason'] as String? ?? 'other',
      status: json['status'] as String? ?? 'new',
      alreadyReported: json['already_reported'] as bool? ?? false,
    );
  }
}

abstract interface class ModerationRepository {
  Future<ContentReport> report({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? comment,
  });
}

/// Максимальная длина пояснения — как на бэкенде.
const maxReportCommentLength = 500;
