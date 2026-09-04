import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/features/settings/domain/company_details.dart';
import 'package:tourism_mobile/features/settings/domain/legal_documents.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Текстовый документ из раздела «О приложении».
///
/// Один экран на все документы: они отличаются только содержимым, а
/// пять почти одинаковых экранов расходились бы по вёрстке при первой же
/// правке.
class SettingsLegalDocumentScreen extends StatelessWidget {
  const SettingsLegalDocumentScreen({required this.documentId, super.key});

  static const routePath = 'doc/:id';

  final String documentId;

  @override
  Widget build(BuildContext context) {
    final document = legalDocuments
        .where((item) => item.id == documentId)
        .firstOrNull;
    if (document == null) {
      return const SettingsScaffold(
        title: 'Документ:',
        spaceChildren: false,
        children: [
          SettingsFormCard(
            child: Text(
              'Такого документа нет. Обновите приложение — возможно, раздел '
              'переехал.',
              style: AppTypography.settingsRowSubtitle,
            ),
          ),
        ],
      );
    }
    return SettingsScaffold(
      title: '${document.title}:',
      spaceChildren: false,
      children: [
        if (document.updated case final updated?) ...[
          Text(updated, style: AppTypography.settingsRowSubtitle),
          const SizedBox(height: SettingsMetrics.rowGap),
        ],
        for (final section in document.sections) ...[
          SettingsFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.heading,
                  style: AppTypography.settingsRowTitle.copyWith(fontSize: 15),
                ),
                for (final paragraph in section.paragraphs) ...[
                  const SizedBox(height: 8),
                  Text(
                    paragraph,
                    style: AppTypography.settingsRowSubtitle.copyWith(
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: SettingsMetrics.rowGap),
        ],
      ],
    );
  }
}

/// Реквизиты компании — таблица «поле → значение».
class SettingsCompanyDetailsScreen extends StatelessWidget {
  const SettingsCompanyDetailsScreen({super.key});

  static const routePath = 'company';

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Реквизиты компании:',
      spaceChildren: false,
      children: [
        SettingsFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                label: 'Наименование',
                value: companyDetails.legalName,
              ),
              _DetailRow(label: 'Бренд', value: companyDetails.brandName),
              _DetailRow(label: 'ИНН', value: companyDetails.inn),
              _DetailRow(label: 'ОГРН', value: companyDetails.ogrn),
              _DetailRow(label: 'Адрес', value: companyDetails.address),
            ],
          ),
        ),
        const SizedBox(height: SettingsMetrics.rowGap),
        const SettingsFormCard(
          child: Text(
            'Реквизиты нужны, чтобы вы понимали, с кем имеете дело при оплате '
            'Тревел+. Пустые поля мы заполним, как только получим документы.',
            style: AppTypography.settingsRowSubtitle,
          ),
        ),
      ],
    );
  }
}

/// Контакты команды: почта, телефон, мессенджер и время ответа.
class SettingsContactsScreen extends ConsumerWidget {
  const SettingsContactsScreen({super.key});

  static const routePath = 'contacts';

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        showAppNotice(context, 'Не удалось открыть ссылку');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final email = companyDetails.email.isNotEmpty
        ? companyDetails.email
        : (config.supportEmail ?? '');
    return SettingsScaffold(
      title: 'Контактная информация:',
      spaceChildren: false,
      children: [
        if (email.isNotEmpty)
          SettingsNavTile(
            title: 'Почта',
            subtitle: email,
            icon: Icons.mail_outline_rounded,
            dense: true,
            onTap: () => unawaited(_open(context, 'mailto:$email')),
          ),
        if (companyDetails.phone.isNotEmpty) ...[
          const SizedBox(height: SettingsMetrics.rowGap),
          SettingsNavTile(
            title: 'Телефон',
            subtitle: companyDetails.phone,
            icon: Icons.call_outlined,
            dense: true,
            onTap: () => unawaited(
              _open(context, 'tel:${companyDetails.phone.replaceAll(' ', '')}'),
            ),
          ),
        ],
        if (companyDetails.telegram.isNotEmpty) ...[
          const SizedBox(height: SettingsMetrics.rowGap),
          SettingsNavTile(
            title: 'Телеграм',
            subtitle: companyDetails.telegram,
            icon: Icons.send_outlined,
            dense: true,
            onTap: () => unawaited(
              _open(
                context,
                'https://t.me/${companyDetails.telegram.replaceAll('@', '')}',
              ),
            ),
          ),
        ],
        const SizedBox(height: SettingsMetrics.rowGap),
        SettingsFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Когда отвечаем',
                style: AppTypography.settingsRowTitle.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                '${companyDetails.workingHours}. Обычно отвечаем в течение '
                'рабочего дня, по вопросам оплаты — до трёх рабочих дней.',
                style: AppTypography.settingsRowSubtitle.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: SettingsMetrics.rowGap),
        SettingsFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Быстрее — через поддержку',
                style: AppTypography.settingsRowTitle.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                'Обращение из раздела «Поддержка» приходит вместе с версией '
                'приложения и моделью устройства — не нужно объяснять, где '
                'именно всё сломалось.',
                style: AppTypography.settingsRowSubtitle.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(label, style: AppTypography.settingsRowSubtitle),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Уточняется' : value,
              style: AppTypography.settingsRowTitle.copyWith(
                fontSize: 14,
                color: value.isEmpty
                    ? AppColors.secondaryInk
                    : AppColors.settingsInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
