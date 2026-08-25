import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

class AudioGuideCard extends StatelessWidget {
  const AudioGuideCard({
    required this.title,
    required this.image,
    required this.onPlay,
    this.author = 'КрымТрип',
    this.durationLabel = '2ч 48м 17с',
    super.key,
  });

  final String title;
  final ImageProvider image;
  final VoidCallback onPlay;
  final String author;
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryInk.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image(
              image: image,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => const SizedBox.square(
                dimension: 44,
                child: ColoredBox(color: AppColors.controlSurface),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.primaryInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                    color: AppColors.secondaryInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            durationLabel,
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.2,
              color: AppColors.secondaryInk,
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: 'Слушать аудиогид',
            child: SizedBox.square(
              dimension: 44,
              child: Material(
                color: AppColors.elevatedSurface,
                shape: const CircleBorder(
                  side: BorderSide(color: AppColors.hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPlay,
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 26,
                    color: AppColors.primaryInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
