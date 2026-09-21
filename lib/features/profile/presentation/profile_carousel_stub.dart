import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

/// The last card of a profile carousel (design, 2026-09-21): an invitation
/// on one's own profile («Новая статья», «Новый маршрут») or a way to the
/// full list on someone else's («Все статьи», «Все маршруты»). Only added
/// when the carousel already has at least one real card.
class ProfileCarouselStub extends StatelessWidget {
  const ProfileCarouselStub({
    required this.iconAsset,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
    required this.width,
    required this.height,
    super.key,
  });

  final String iconAsset;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;
  final double width;
  final double height;

  // Measured from the design export: the icon blue and a pale wash of it.
  static const _blue = Color(0xFF1E71CA);
  static const _wash = Color(0xFFEEF4FC);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppShadows.tile,
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _wash,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: _blue),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  const Spacer(),
                  Image.asset(
                    iconAsset,
                    width: 88,
                    height: 88,
                    filterQuality: FilterQuality.high,
                    excludeFromSemantics: true,
                  ),
                  const Spacer(),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.settingsRowTitle.copyWith(
                      fontSize: 15,
                      color: AppColors.primaryInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.settingsRowSubtitle.copyWith(
                      fontSize: 12,
                      height: 1.3,
                      color: AppColors.secondaryInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0x1F1E71CA)),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 40,
                    width: width * 0.66,
                    child: OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.elevatedSurface,
                        foregroundColor: AppColors.primaryInk,
                        side: const BorderSide(color: Color(0xFFD9D9DB)),
                        shape: const StadiumBorder(),
                        textStyle: AppTypography.settingsRowSubtitle.copyWith(
                          fontSize: 13,
                          color: AppColors.primaryInk,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
