import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_list_skeleton.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/data/invite_privacy_repository.dart';
import 'package:tourism_mobile/features/companions/presentation/companion_sheets.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

/// «Приглашения и блокировки» in the profile settings (FRONTEND-63, spec 11b
/// D15): who may invite me to a group or to co-author a route, and the
/// people I blocked.
class InvitePrivacyScreen extends ConsumerStatefulWidget {
  const InvitePrivacyScreen({super.key});

  static const routePath = 'invites';

  @override
  ConsumerState<InvitePrivacyScreen> createState() =>
      _InvitePrivacyScreenState();
}

class _InvitePrivacyScreenState extends ConsumerState<InvitePrivacyScreen> {
  InvitePolicy? _pending;
  final _unblocking = <String>{};

  Future<void> _setPolicy(InvitePolicy policy) async {
    setState(() => _pending = policy);
    try {
      await ref.read(invitePrivacyRepositoryProvider).setPolicy(policy);
      ref.invalidate(invitePolicyProvider);
      await ref.read(invitePolicyProvider.future);
    } on Object catch (error) {
      if (mounted) {
        showAppNotice(
          context,
          companionErrorText(error),
          kind: AppNoticeKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  Future<void> _unblock(BlockedPerson person) async {
    setState(() => _unblocking.add(person.userId));
    try {
      await ref.read(invitePrivacyRepositoryProvider).unblock(person.userId);
      ref.invalidate(blockedPeopleProvider);
      if (mounted) {
        showAppNotice(context, '${person.displayName} разблокирован');
      }
    } on Object catch (error) {
      if (mounted) {
        showAppNotice(
          context,
          companionErrorText(error),
          kind: AppNoticeKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _unblocking.remove(person.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = _pending ?? ref.watch(invitePolicyProvider).valueOrNull;
    final blocked = ref.watch(blockedPeopleProvider);
    return SettingsScaffold(
      title: 'Приглашения:',
      children: [
        const Text(
          'Кто может звать вас в совместное прохождение и в соавторы '
          'маршрута',
          style: AppTypography.settingsRowSubtitle,
        ),
        SettingsSectionCard(
          children: [
            for (final (value, title, subtitle) in const [
              (
                InvitePolicy.mutual,
                'Взаимные подписки',
                'Те, на кого вы подписаны и кто подписан на вас',
              ),
              (
                InvitePolicy.nobody,
                'Никто',
                'Приглашения не придут, в группу можно войти по коду',
              ),
            ])
              SettingsNavTile(
                key: ValueKey('invite-policy-${value.name}'),
                title: title,
                subtitle: subtitle,
                dense: true,
                trailing: Icon(
                  policy == value
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: policy == value
                      ? AppColors.primaryInk
                      : AppColors.secondaryInk,
                ),
                onTap: policy == value || _pending != null
                    ? null
                    : () => unawaited(_setPolicy(value)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Заблокированные', style: AppTypography.sectionTitle),
        const Text(
          'Заблокированный человек не может позвать вас в группу или в '
          'соавторы, а вы его. Он не узнает о блокировке.',
          style: AppTypography.settingsRowSubtitle,
        ),
        blocked.when(
          skipLoadingOnRefresh: true,
          loading: () => const AppListSkeleton(
            rows: 2,
            rowHeight: 56,
            roundLeading: true,
            padding: EdgeInsets.zero,
          ),
          error: (error, _) => Text(
            companionErrorText(error),
            style: AppTypography.settingsRowSubtitle,
          ),
          data: (people) => people.isEmpty
              ? const Text(
                  'Никого нет',
                  style: AppTypography.settingsRowSubtitle,
                )
              : SettingsSectionCard(
                  children: [
                    for (final person in people)
                      SettingsNavTile(
                        key: ValueKey('blocked-${person.userId}'),
                        title: person.displayName,
                        icon: Icons.block_rounded,
                        dense: true,
                        trailing: TextButton(
                          onPressed: _unblocking.contains(person.userId)
                              ? null
                              : () => unawaited(_unblock(person)),
                          child: const Text('Разблокировать'),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
