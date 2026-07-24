import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      primary: AppColors.ink,
      surface: AppColors.elevatedSurface,
      error: AppColors.error,
      brightness: Brightness.light,
    );

    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.field)),
      borderSide: BorderSide(color: Color(0xFFD5D5D8)),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppFonts.rubik,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.mist,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.mist,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0x35FFFFFF),
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.field)),
          borderSide: BorderSide(color: AppColors.primaryInk, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.field)),
          borderSide: BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.field)),
          borderSide: BorderSide(color: AppColors.error, width: 1.2),
        ),
        hintStyle: TextStyle(
          color: AppColors.inkSoft,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          fontFamily: AppFonts.rubik,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.mistDark,
          disabledForegroundColor: AppColors.inkSoft,
          shape: const StadiumBorder(),
          textStyle: AppTypography.button,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.ink,
        labelStyle: AppTypography.chip,
        secondaryLabelStyle: AppTypography.chip.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          side: const BorderSide(color: Color(0xFFE4E4E8)),
        ),
        side: const BorderSide(color: Color(0xFFE4E4E8)),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 34,
          fontWeight: FontWeight.w600,
          height: 1.1,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        headlineMedium: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 34,
          fontWeight: FontWeight.w600,
          height: 1.08,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        headlineSmall: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        titleLarge: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        bodyLarge: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: AppColors.inkSoft,
          height: 1.35,
        ),
        bodyMedium: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: AppColors.inkSoft,
        ),
        labelLarge: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
