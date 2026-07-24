import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/theme/app_colors.dart';
import 'package:tourism_mobile/core/theme/app_fonts.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      primary: AppColors.ink,
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppFonts.rubik,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.mist,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.2),
        ),
        hintStyle: const TextStyle(
          color: AppColors.inkSoft,
          fontSize: 16,
          fontFamily: AppFonts.rubik,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: AppFonts.rubik,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.mist,
        selectedColor: AppColors.ink,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontFamily: AppFonts.rubik,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontFamily: AppFonts.rubik,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.glass,
        indicatorColor: AppColors.mistDark,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.ink : AppColors.inkSoft,
          );
        }),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: 1.1,
          color: AppColors.ink,
          letterSpacing: -0.5,
          fontVariations: [FontVariation('wght', 800)],
        ),
        headlineMedium: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.15,
          color: AppColors.ink,
          letterSpacing: -0.4,
          fontVariations: [FontVariation('wght', 800)],
        ),
        headlineSmall: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          fontVariations: [FontVariation('wght', 700)],
        ),
        titleLarge: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          fontVariations: [FontVariation('wght', 700)],
        ),
        titleMedium: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          fontVariations: [FontVariation('wght', 600)],
        ),
        bodyLarge: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.inkSoft,
          height: 1.35,
          fontVariations: [FontVariation('wght', 400)],
        ),
        bodyMedium: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.inkSoft,
          fontVariations: [FontVariation('wght', 400)],
        ),
        labelLarge: TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          fontVariations: [FontVariation('wght', 600)],
        ),
      ),
    );
  }
}
