import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/moderation/application/moderation_providers.dart';
import 'package:tourism_mobile/features/moderation/domain/content_report.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Шторка «Пожаловаться»: причина списком и необязательное пояснение.
///
/// Жалоба ничего не скрывает сама — она ставит материал в очередь модерации,
/// и человеку об этом честно говорится в подписи: иначе от кнопки ждут
/// мгновенного исчезновения комментария.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required ReportTargetType targetType,
  required String targetId,
  required String title,
}) async {
  final session = ref.read(sessionProvider);
  if (!session.isAuthenticated) {
    // Анонимную жалобу нечем ограничить одной на человека — сервер её и не
    // примет, поэтому сразу ведём на вход.
    unawaited(context.pushNamed(AppRouteNames.authIdentity));
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.elevatedSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _ReportSheet(
        targetType: targetType,
        targetId: targetId,
        title: title,
      ),
    ),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.targetType,
    required this.targetId,
    required this.title,
  });

  final ReportTargetType targetType;
  final String targetId;
  final String title;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final _comment = TextEditingController();
  ReportReason? _reason;
  var _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      final report = await ref
          .read(moderationRepositoryProvider)
          .report(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: reason,
            comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      showAppNotice(
        context,
        report.alreadyReported
            ? 'Вы уже жаловались на это — жалоба в работе'
            : 'Спасибо, жалоба отправлена модераторам',
      );
    } on AppFailure catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppNotice(context, error.message);
    } on Object {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppNotice(context, 'Не удалось отправить жалобу');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          12 + bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Пожаловаться',
              style: AppTypography.sectionTitle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.settingsRowSubtitle,
            ),
            const SizedBox(height: 14),
            for (final reason in ReportReason.values) ...[
              _ReasonRow(
                label: reason.label,
                selected: _reason == reason,
                onTap: () => setState(() => _reason = reason),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            TextField(
              controller: _comment,
              maxLength: maxReportCommentLength,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Что не так? (необязательно)',
                filled: true,
                fillColor: const Color(0xFFF1F1F3),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                key: const ValueKey('report-submit'),
                onPressed: _reason == null || _sending ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryInk,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.capsule),
                  ),
                ),
                child: Text(_sending ? 'Отправляем…' : 'Отправить'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Материал не исчезнет сразу: жалобу разбирает модератор.',
              style: AppTypography.settingsRowSubtitle.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentBlue.withValues(alpha: 0.08)
                : const Color(0xFFF1F1F3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.accentBlue : AppColors.hairline,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.chip.copyWith(
                    fontSize: 14,
                    color: AppColors.primaryInk,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppColors.accentBlue,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
