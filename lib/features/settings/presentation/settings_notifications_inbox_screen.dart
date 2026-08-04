import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

/// Mock inbox: new / read sections. Server feed lands with notifications API.
class SettingsNotificationsInboxScreen extends ConsumerWidget {
  const SettingsNotificationsInboxScreen({super.key});

  static const maxBodyChars = 180;
  static const maxNameChars = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsInboxProvider);
    final unread = items.where((n) => n.isUnread).toList();
    final read = items.where((n) => !n.isUnread).toList();

    return SettingsScaffold(
      title: 'Мои уведомления:',
      showSave: true,
      onSave: () {
        ref.read(notificationsInboxProvider.notifier).markAllRead();
      },
      spaceChildren: false,
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
              onTap: () => ref
                  .read(notificationsInboxProvider.notifier)
                  .markRead(unread[i].id),
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
          const Text('Пока пусто', style: AppTypography.settingsRowSubtitle)
        else
          for (var i = 0; i < read.length; i++) ...[
            if (i > 0) const SizedBox(height: SettingsMetrics.rowGap),
            _InboxTile(item: read[i]),
          ],
        const SizedBox(height: 120),
      ],
    );
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
                  unawaited(AppHaptics.selectionClick());
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
