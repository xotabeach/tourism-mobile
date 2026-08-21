import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

/// Compact place chip inside AI chat (allowlisted fields only — no HTML).
class ChatPlaceChip extends StatelessWidget {
  const ChatPlaceChip({
    required this.title,
    this.subtitle,
    this.durationMinutes,
    this.imageUrl,
    super.key,
  });

  final String title;
  final String? subtitle;
  final int? durationMinutes;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final duration = durationMinutes;
    final meta = <String>[
      if (subtitle != null && subtitle!.trim().isNotEmpty) subtitle!.trim(),
      if (duration != null && duration > 0) '$duration мин',
    ].join(' · ');

    return Material(
      color: AppColors.controlSurface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 148,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 72,
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AppColors.elevatedSurface),
                    )
                  : const ColoredBox(color: AppColors.elevatedSurface),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sectionTitle.copyWith(fontSize: 13),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.greetingSubtitle.copyWith(
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
