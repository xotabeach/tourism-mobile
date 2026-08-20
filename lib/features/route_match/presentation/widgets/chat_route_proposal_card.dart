import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

/// Structured proposal card for AI chat (before draft / create).
///
/// Renders allowlisted fields only — never HTML / WebView.
class ChatRouteProposalCard extends StatelessWidget {
  const ChatRouteProposalCard({
    required this.title,
    required this.stopsCount,
    required this.durationMinutes,
    this.coverUrl,
    this.onCreate,
    this.onSaveDraft,
    this.onRefine,
    super.key,
  });

  final String title;
  final int stopsCount;
  final int durationMinutes;
  final String? coverUrl;
  final VoidCallback? onCreate;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onRefine;

  @override
  Widget build(BuildContext context) {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    final durationLabel = hours > 0
        ? (mins > 0 ? '$hours ч $mins мин' : '$hours ч')
        : '$mins мин';

    return Material(
      color: AppColors.elevatedSurface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (coverUrl != null && coverUrl!.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: AppColors.controlSurface),
              ),
            )
          else
            const ColoredBox(
              color: AppColors.controlSurface,
              child: SizedBox(height: 96),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.sectionTitle.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 6),
                Text(
                  '$stopsCount точек · $durationLabel',
                  style: AppTypography.greetingSubtitle,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onCreate != null)
                      FilledButton(
                        onPressed: onCreate,
                        child: const Text('Создать'),
                      ),
                    if (onSaveDraft != null)
                      OutlinedButton(
                        onPressed: onSaveDraft,
                        child: const Text('В черновик'),
                      ),
                    if (onRefine != null)
                      TextButton(
                        onPressed: onRefine,
                        child: const Text('Уточнить'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
