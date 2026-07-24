import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';

abstract final class AppFonts {
  static const String rubik = 'Rubik';
}

abstract final class AppTypography {
  static const TextStyle welcomeBrand = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 4,
  );

  static const TextStyle welcomeTitle = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 36,
    fontWeight: FontWeight.w600,
    height: 1.08,
    letterSpacing: 0.2,
  );

  static const TextStyle welcomeSubtitle = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.42,
    letterSpacing: 0.3,
  );

  static const TextStyle greeting = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: 0,
    color: AppColors.primaryInk,
  );

  static const TextStyle greetingSubtitle = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.25,
    letterSpacing: 0,
    color: AppColors.secondaryInk,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0,
    color: AppColors.primaryInk,
  );

  static const TextStyle sectionAction = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0,
    color: AppColors.secondaryInk,
  );

  static const TextStyle routeTitle = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.12,
    letterSpacing: 0,
  );

  static const TextStyle routeMetadata = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.25,
    letterSpacing: 0,
  );

  static const TextStyle chip = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.15,
    letterSpacing: 0,
  );

  static const TextStyle button = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0,
  );

  static const TextStyle coach = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.3,
    letterSpacing: 0,
  );
}
