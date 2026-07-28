import 'package:flutter/material.dart';

abstract final class TrackerColors {
  // ── Backgrounds ──────────────────────────────────────────
  static const background = Color(0xFFF0F2F5);
  static const backgroundElevated = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFE8ECF1);
  static const surfaceAlt = surfaceMuted;
  static const surfaceDark = Color(0xFF0B1120);
  static const surfaceDarkElevated = Color(0xFF111827);

  // ── Borders ──────────────────────────────────────────────
  static const line = Color(0xFFD1D9E6);
  static const lineBright = Color(0xFFB0BCCE);
  static const lineSubtle = Color(0xFFE5E9F0);

  // ── Authority / Brand ────────────────────────────────────
  static const navy900 = Color(0xFF0B1120);
  static const navy800 = Color(0xFF111827);
  static const navy700 = Color(0xFF1E293B);
  static const navy600 = Color(0xFF253442);
  static const navy500 = Color(0xFF334155);
  static const primaryDark = Color(0xFF0F2440);
  static const communicationBlue = Color(0xFF2563EB);
  static const communicationBlueLight = Color(0xFF3B82F6);
  static const primary = communicationBlue;

  // ── Status ───────────────────────────────────────────────
  static const technicalGreen = Color(0xFF059669);
  static const technicalGreenLight = Color(0xFF10B981);
  static const attentionAmber = Color(0xFFD97706);
  static const attentionAmberLight = Color(0xFFF59E0B);
  static const failureRed = Color(0xFFDC2626);
  static const failureRedLight = Color(0xFFEF4444);
  static const infoCyan = Color(0xFF0891B2);

  // ── Text ─────────────────────────────────────────────────
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);
  static const textOnDark = Color(0xFFF1F5F9);
  static const textOnDarkMuted = Color(0xFF94A3B8);

  // ── Gradients ────────────────────────────────────────────
  static const gradientHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy900, navy800, navy700],
  );

  static const gradientCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFAFBFC), Color(0xFFF8FAFC)],
  );

  static const gradientGreen = LinearGradient(
    colors: [technicalGreen, technicalGreenLight],
  );

  static const gradientBlue = LinearGradient(
    colors: [communicationBlue, communicationBlueLight],
  );

  static const gradientAmber = LinearGradient(
    colors: [attentionAmber, attentionAmberLight],
  );

  static const gradientRed = LinearGradient(
    colors: [failureRed, failureRedLight],
  );
}
