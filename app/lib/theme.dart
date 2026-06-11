import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// HealthPass brand palette (joinhealthpass.com): navy structure + coral accent.
abstract class AppColors {
  static const navy = Color(0xFF0E2A47);
  static const navy2 = Color(0xFF0A2138);
  static const coral = Color(0xFFFF736A);
  static const coralStrong = Color(0xFFF94044);
  static const coralSoft = Color(0xFFFFF3F2);
  static const coralLine = Color(0xFFFFD6D2);
  static const periwinkle = Color(0xFF7FA2FF);
  static const ink = Color(0xFF1F2A37);
  static const muted = Color(0xFF5B6675);
  static const line = Color(0xFFE4E7EC);
  static const bg = Color(0xFFEFF2F6);
  static const field = Color(0xFFF7F8FA);
  static const white = Color(0xFFFFFFFF);
}

/// Spacing scale.
abstract class Gap {
  static const xs = SizedBox(height: 4, width: 4);
  static const sm = SizedBox(height: 8, width: 8);
  static const md = SizedBox(height: 16, width: 16);
  static const lg = SizedBox(height: 24, width: 24);
  static const xl = SizedBox(height: 32, width: 32);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.coral,
      surface: AppColors.white,
      error: AppColors.coralStrong,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    headlineMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.navy),
    headlineSmall: GoogleFonts.inter(
        fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.navy),
    titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.navy),
    titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.ink),
    labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w700),
  );

  return base.copyWith(
    textTheme: textTheme,
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 3,
      shadowColor: const Color(0x140E2A47),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.coral.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.line, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.coralStrong,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: GoogleFonts.inter(color: AppColors.muted),
      labelStyle: GoogleFonts.inter(color: AppColors.muted, fontWeight: FontWeight.w600),
      floatingLabelStyle: GoogleFonts.inter(color: AppColors.navy, fontWeight: FontWeight.w700),
      prefixStyle: GoogleFonts.inter(color: AppColors.ink),
      border: _border(AppColors.line, 1.5),
      enabledBorder: _border(AppColors.line, 1.5),
      focusedBorder: _border(AppColors.coral, 2),
      errorBorder: _border(AppColors.coralStrong, 1.5),
      focusedErrorBorder: _border(AppColors.coralStrong, 2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      contentTextStyle: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

OutlineInputBorder _border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
