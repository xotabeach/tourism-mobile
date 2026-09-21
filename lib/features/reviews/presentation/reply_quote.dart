import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

/// What a reply answers: the author and two lines of their text behind a
/// dark bar on the left. One look for route and place reviews and for
/// article comments, both on a published reply and above the reply field
/// (where [onCancel] adds the cross that drops the reply).
class ReplyQuote extends StatelessWidget {
  const ReplyQuote({
    required this.title,
    required this.body,
    this.onCancel,
    super.key,
  });

  final String title;
  final String body;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final onCancel = this.onCancel;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.controlSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 3,
              decoration: const BoxDecoration(
                color: AppColors.primaryInk,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 8,
                  bottom: 8,
                  right: onCancel == null ? 10 : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 12,
                        height: 1.3,
                        color: AppColors.secondaryInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onCancel != null)
              IconButton(
                tooltip: 'Отменить ответ',
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
