import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF000000);
  static const Color onPrimary = Colors.white;
  static const Color accent = Color(0xFFCB97FF);
  static const Color black = Color(0xFF000000);
  static const Color onSurface = Color(0xFF1D1B20);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  static const Color surfaceContainerHigh = Color(0xFFECE6F0);
  static const Color surfaceTint = Color(0xFFF6EDFB);
  static const Color outline = Color(0xFFCAC4D0);
  static const Color mutedText = Color(0x80000000);
  static const Color danger = Color(0xFFB3261E);
  static const Color success = Color(0xFF14A33A);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: Colors.white,
      onSurface: AppColors.onSurface,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: Colors.white,
  );

  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w500,
        height: 44 / 36,
        color: AppColors.black,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        letterSpacing: 0.5,
        color: AppColors.black,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 24 / 16,
        letterSpacing: 0.15,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0.1,
      ),
    ),
  );
}
