import 'package:flutter/material.dart';

import 'tracker_colors.dart';
import 'tracker_radius.dart';
import 'tracker_text_styles.dart';

export 'tracker_colors.dart';
export 'tracker_radius.dart';
export 'tracker_spacing.dart';
export 'tracker_shadows.dart';
export 'tracker_text_styles.dart';

abstract final class TrackerTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: TrackerColors.communicationBlue,
      brightness: Brightness.light,
      surface: TrackerColors.surface,
      error: TrackerColors.failureRed,
    ).copyWith(
      primary: TrackerColors.communicationBlue,
      onPrimary: Colors.white,
      secondary: TrackerColors.technicalGreen,
      tertiary: TrackerColors.attentionAmber,
      onSurface: TrackerColors.textPrimary,
      onSurfaceVariant: TrackerColors.textSecondary,
      outline: TrackerColors.lineBright,
      outlineVariant: TrackerColors.line,
    );
    return _build(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: TrackerColors.communicationBlue,
      brightness: Brightness.dark,
      surface: TrackerColors.surface,
      error: TrackerColors.failureRed,
    ).copyWith(
      primary: TrackerColors.communicationBlue,
      secondary: TrackerColors.technicalGreen,
      tertiary: TrackerColors.attentionAmber,
      onSurface: TrackerColors.textPrimary,
      outline: TrackerColors.lineBright,
      outlineVariant: TrackerColors.line,
    );

    return _build(scheme, Brightness.dark);
  }

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isLight ? TrackerColors.background : const Color(0xFF070B10),
    );

    final textPrimary =
        isLight ? TrackerColors.textPrimary : const Color(0xFFEAF2F8);
    final textSecondary =
        isLight ? TrackerColors.textSecondary : const Color(0xFF96A9B8);
    final surface = isLight ? TrackerColors.surface : const Color(0xFF0E151D);
    final surfaceMuted =
        isLight ? TrackerColors.surfaceMuted : const Color(0xFF0B1218);
    final line = isLight ? TrackerColors.line : const Color(0xFF253442);

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: textSecondary,
        displayColor: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: TrackerRadius.large,
          side: BorderSide(color: line),
        ),
      ),
      dividerColor: line,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TrackerColors.communicationBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: TrackerColors.surfaceMuted,
          disabledForegroundColor: TrackerColors.textMuted,
          minimumSize: const Size(0, 44),
          shape: const RoundedRectangleBorder(
            borderRadius: TrackerRadius.medium,
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: line),
          minimumSize: const Size(0, 44),
          shape: const RoundedRectangleBorder(
            borderRadius: TrackerRadius.medium,
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: TrackerRadius.medium,
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: TrackerRadius.medium,
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: TrackerRadius.medium,
          borderSide:
              BorderSide(color: TrackerColors.communicationBlue, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(borderRadius: TrackerRadius.large),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: TrackerColors.communicationBlue,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: TrackerColors.communicationBlue.withValues(alpha: 0.12),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? TrackerColors.primaryDark
                  : TrackerColors.textSecondary,
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            )),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TrackerColors.background,
        foregroundColor: TrackerColors.primaryDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      extensions: [
        TrackerTypography(
          overline: TrackerTextStyles.overline.copyWith(color: scheme.primary),
          sectionTitle:
              TrackerTextStyles.sectionTitle.copyWith(color: textPrimary),
          cardTitle: TrackerTextStyles.cardTitle.copyWith(color: textPrimary),
          body: TrackerTextStyles.body.copyWith(color: textSecondary),
          telemetry: TrackerTextStyles.telemetry.copyWith(color: textSecondary),
        ),
      ],
    );
  }
}

@immutable
class TrackerTypography extends ThemeExtension<TrackerTypography> {
  final TextStyle overline;
  final TextStyle sectionTitle;
  final TextStyle cardTitle;
  final TextStyle body;
  final TextStyle telemetry;

  const TrackerTypography({
    required this.overline,
    required this.sectionTitle,
    required this.cardTitle,
    required this.body,
    required this.telemetry,
  });

  @override
  TrackerTypography copyWith({
    TextStyle? overline,
    TextStyle? sectionTitle,
    TextStyle? cardTitle,
    TextStyle? body,
    TextStyle? telemetry,
  }) =>
      TrackerTypography(
        overline: overline ?? this.overline,
        sectionTitle: sectionTitle ?? this.sectionTitle,
        cardTitle: cardTitle ?? this.cardTitle,
        body: body ?? this.body,
        telemetry: telemetry ?? this.telemetry,
      );

  @override
  TrackerTypography lerp(
    covariant ThemeExtension<TrackerTypography>? other,
    double t,
  ) {
    if (other is! TrackerTypography) return this;
    return TrackerTypography(
      overline: TextStyle.lerp(overline, other.overline, t)!,
      sectionTitle: TextStyle.lerp(sectionTitle, other.sectionTitle, t)!,
      cardTitle: TextStyle.lerp(cardTitle, other.cardTitle, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      telemetry: TextStyle.lerp(telemetry, other.telemetry, t)!,
    );
  }
}

extension TrackerThemeData on ThemeData {
  TrackerTypography get trackerTypography =>
      extension<TrackerTypography>() ??
      const TrackerTypography(
        overline: TrackerTextStyles.overline,
        sectionTitle: TrackerTextStyles.sectionTitle,
        cardTitle: TrackerTextStyles.cardTitle,
        body: TrackerTextStyles.body,
        telemetry: TrackerTextStyles.telemetry,
      );
}
