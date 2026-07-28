import 'package:tracker_studio/core/design/tracker_colors.dart';

/// UI design tokens used by the theming system.
/// This mirrors the existing TrackerColors but provides
/// names expected by the new AppTheme implementation.
abstract final class AppColors {
  // Primary palette (cyan/teal shades)
  static const primary = TrackerColors.communicationBlue;
  static const primaryLight = TrackerColors.communicationBlueLight;
  static const primaryDark = TrackerColors.primaryDark;

  // Success / technical green
  static const success = TrackerColors.technicalGreen;
  static const successLight = TrackerColors.technicalGreenLight;

  // Attention / amber
  static const warning = TrackerColors.attentionAmber;
  static const warningLight = TrackerColors.attentionAmberLight;

  // Error / failure red
  static const error = TrackerColors.failureRed;
  static const errorLight = TrackerColors.failureRedLight;

  // Surface (background) tokens
  static const surface0 = TrackerColors.surface;
  static const surface1 = TrackerColors.surfaceRaised;
  static const surface2 = TrackerColors.surfaceAlt;

  // Text colors
  static const textPrimary = TrackerColors.textPrimary;
  static const textSecondary = TrackerColors.textSecondary;
  static const textMuted = TrackerColors.textMuted;
}
