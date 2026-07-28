import 'package:flutter/material.dart';

import 'tracker_colors.dart';

abstract final class TrackerTextStyles {
  static const overline = TextStyle(
    color: TrackerColors.communicationBlue,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    height: 1.2,
  );

  static const sectionTitle = TextStyle(
    color: TrackerColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const cardTitle = TextStyle(
    color: TrackerColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.3,
  );

  static const body = TextStyle(
    color: TrackerColors.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const bodyStrong = TextStyle(
    color: TrackerColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  static const telemetry = TextStyle(
    color: TrackerColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.35,
  );

  static const telemetryLarge = TextStyle(
    color: TrackerColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static const label = TextStyle(
    color: TrackerColors.textMuted,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.2,
  );
}
