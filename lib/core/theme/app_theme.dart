import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ui_tokens.dart';
import '../design/tracker_radius.dart';

class AppTheme {
  // Light theme
  static ThemeData light() {
    final base = ThemeData.light();
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryLight,
        secondary: AppColors.success,
        background: AppColors.surface0,
        surface: AppColors.surface2,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.surface0,
      primaryColor: AppColors.primary,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w400),
        titleLarge: base.textTheme.titleLarge?.copyWith(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w600),
        titleMedium: base.textTheme.titleMedium?.copyWith(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w600),
        titleSmall: base.textTheme.titleSmall?.copyWith(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        labelLarge: base.textTheme.labelLarge?.copyWith(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium: base.textTheme.labelMedium?.copyWith(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: base.textTheme.labelSmall?.copyWith(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
      ),
      cardTheme: const CardThemeData(shape: RoundedRectangleBorder(borderRadius: TrackerRadius.medium)),
      buttonTheme: const ButtonThemeData(shape: RoundedRectangleBorder(borderRadius: TrackerRadius.small)),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  // Dark theme – mirrors light but with dark surfaces
  static ThemeData dark() {
    final base = ThemeData.dark();
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryDark,
        secondary: AppColors.success,
        background: AppColors.surface0,
        surface: AppColors.surface2,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.surface0,
      primaryColor: AppColors.primary,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w400),
        titleLarge: base.textTheme.titleLarge?.copyWith(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w600),
        titleMedium: base.textTheme.titleMedium?.copyWith(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w600),
        titleSmall: base.textTheme.titleSmall?.copyWith(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        labelLarge: base.textTheme.labelLarge?.copyWith(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium: base.textTheme.labelMedium?.copyWith(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: base.textTheme.labelSmall?.copyWith(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
      ),
      cardTheme: const CardThemeData(shape: RoundedRectangleBorder(borderRadius: TrackerRadius.medium)),
      buttonTheme: const ButtonThemeData(shape: RoundedRectangleBorder(borderRadius: TrackerRadius.small)),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
