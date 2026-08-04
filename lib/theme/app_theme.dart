import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final ThemeData light = ThemeData(
    colorScheme:
        ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)), // teal
    brightness: Brightness.light,
    textTheme: GoogleFonts.interTextTheme(),
    useMaterial3: true,
  );

  static final ThemeData dark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00796B),
      brightness: Brightness.dark,
    ),
    brightness: Brightness.dark,
    textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme),
    useMaterial3: true,
  );
}
