import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Server-backed inbox (in-app). System push (FCM) is deferred.
class SettingsNotificationsInboxScreen extends ConsumerWidget {
  const SettingsNotificationsInboxScreen({super.key});

  static const maxBodyChars = 180;
  static const maxNameChars = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsInboxProvider);

    return SettingsScaffold(
      title: 'Мои уведомления:',
      showSave: true,
      onSave: () {
        unawaited(ref.read(notificationsInboxProvider.notifier).markAllRead());
      },
      spaceChildren: false,
      children: [
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Не удалось загрузить уведомления',
                style: AppTypography.settingsRowSubtitle,
              ),
              TextButton(
                onPressed: () =>
                    ref.read(notificationsInboxProvider.notifier).refresh(),
                child: const Text('Повторить'),
              ),
            ],
          ),
          data: (items) {
            final unread = items.where((n) => n.isUnread).toList();
            final read = items.where((n) => !n.isUnread).toList();
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'У вас нет новых уведомлений',
                  style: AppTypography.settingsRowSubtitle,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unread.isNotEmpty) ...[
                  Text(
                    'Новые уведомления:',
                    style: AppTypography.settingsRowTitle.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < unread.length; i++) ...[
                    if (i > 0) const SizedBox(height: SettingsMetrics.rowGap),
                    _InboxTile(
                      item: unread[i],
                      onTap: () => _openNotification(context, ref, unread[i]),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const SettingsHairline(),
                  const SizedBox(height: 18),
                ],
                Text(
                  'Прочитанные:',
                  style: AppTypography.settingsRowTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 12),
                if (read.isEmpty)
                  const Text(
                    'Пока пусто',
                    style: AppTypography.settingsRowSubtitle,
                  )
                else
                  for (var i = 0; i < read.length; i++) ...[
                    if (i > 0) const SizedBox(height: SettingsMetrics.rowGap),
                    _InboxTile(
                      item: read[i],
                      onTap: () => _openNotification(context, ref, read[i]),
                    ),
                  ],
                const SizedBox(height: 120),
              ],
            );
          },
        ),
      ],
    );
  }

  static Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    InboxNotification item,
  ) async {
    unawaited(AppHaptics.selectionClick());
    unawaited(ref.read(notificationsInboxProvider.notifier).markRead(item.id));
    if (item.targetType == 'route' &&
        item.targetId != null &&
        item.targetId!.isNotEmpty) {
      await context.pushNamed(
        AppRouteNames.routeDetails,
        pathParameters: {'id': item.targetId!},
      );
    }
  }

  static String clampText(String value, int max) {
    final trimmed = value.trim();
    if (trimmed.length <= max) {
      return trimmed;
    }
    return '${trimmed.substring(0, max)}…';
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.item, this.onTap});

  final InboxNotification item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = SettingsNotificationsInboxScreen.clampText(
      item.actorName,
      SettingsNotificationsInboxScreen.maxNameChars,
    );
    final body = SettingsNotificationsInboxScreen.clampText(
      item.body,
      SettingsNotificationsInboxScreen.maxBodyChars,
    );
    final initial = name.isEmpty ? '?' : String.fromCharCode(name.runes.first);

    final radius = BorderRadius.circular(AppRadii.settingsTile);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppShadows.settingsTile,
      ),
      child: Material(
        color: AppColors.elevatedSurface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  onTap!();
                },
          borderRadius: radius,
          child: SizedBox(
            height: SettingsMetrics.rowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE5E5EA),
                    child: Text(
                      initial.toUpperCase(),
                      style: AppTypography.settingsRowTitle.copyWith(
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.settingsRowTitle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.settingsRowSubtitle,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
