import 'package:tourism_mobile/features/moderation/domain/content_report.dart';

/// Мок повторяет главное правило сервера: вторая жалоба на тот же объект
/// возвращает первую, а не заводит новую.
final class MockModerationRepository implements ModerationRepository {
  final _sent = <String, ContentReport>{};

  @override
  Future<ContentReport> report({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? comment,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final key = '${targetType.apiValue}:$targetId';
    final existing = _sent[key];
    if (existing != null) {
      return ContentReport(
        id: existing.id,
        reason: existing.reason,
        status: existing.status,
        alreadyReported: true,
      );
    }
    final report = ContentReport(
      id: 'mock-report-${DateTime.now().microsecondsSinceEpoch}',
      reason: reason.apiValue,
      status: 'new',
      alreadyReported: false,
    );
    _sent[key] = report;
    return report;
  }
}
