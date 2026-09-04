import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_list_skeleton.dart';
import 'package:tourism_mobile/features/route_match/application/route_match_providers.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

String routeMatchDurationLabel(RouteDurationOption option) {
  return switch (option) {
    RouteDurationOption.d1_2 => '1–2 дня',
    RouteDurationOption.d3_5 => '3–5 дней',
    RouteDurationOption.d6_7 => '6–7 дней',
    RouteDurationOption.d7plus => '7+ дней',
  };
}

String chatSessionLabel(RoutePlanningSession session) {
  final c = session.constraints;
  final parts = [
    c.city,
    routeMatchDurationLabel(c.duration),
    if (c.interests.isNotEmpty) c.interests.first,
  ];
  return parts.join(' · ');
}

const _months = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

String _formatSessionDate(DateTime local) {
  final day = local.day;
  final month = _months[local.month - 1];
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$day $month, $hh:$mm';
}

/// "История чатов с ИИ" — Settings entry point onto past
/// [RoutePlanningSession]s. Tapping one resumes it in [RouteMatchScreen]
/// with its transcript replayed (see `resumeSession` there).
class ChatHistoryScreen extends ConsumerWidget {
  const ChatHistoryScreen({super.key});

  static const routePath = 'chat-history';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(chatSessionsProvider);

    return SettingsScaffold(
      title: 'История чатов с ИИ',
      children: [
        sessionsAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          skipError: true,
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: AppListSkeleton(rows: 5, showLeading: false),
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Не удалось загрузить историю чатов',
                style: AppTypography.settingsRowSubtitle,
              ),
              TextButton(
                onPressed: () => ref.invalidate(chatSessionsProvider),
                child: const Text('Повторить'),
              ),
            ],
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'У вас пока нет чатов с ИИ-агентом',
                  style: AppTypography.settingsRowSubtitle,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < page.items.length; i++) ...[
                  if (i > 0) const SizedBox(height: SettingsMetrics.rowGap),
                  _ChatSessionTile(
                    session: page.items[i],
                    onTap: () => unawaited(
                      context.pushNamed<void>(
                        AppRouteNames.routeMatchResume,
                        extra: page.items[i],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ChatSessionTile extends StatelessWidget {
  const _ChatSessionTile({required this.session, this.onTap});

  final RoutePlanningSession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final when = session.updatedAt ?? session.createdAt;
    final subtitle = when == null
        ? (session.status == 'closed' ? 'Завершён' : 'Активен')
        : _formatSessionDate(when.toLocal());
    return SettingsNavTile(
      icon: Icons.forum_outlined,
      title: chatSessionLabel(session),
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}
