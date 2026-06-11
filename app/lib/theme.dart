import 'package:flutter/material.dart';

/// HealthPass brand palette (joinhealthpass.com): navy structure + coral accent.
const Color kNavy = Color(0xFF0E2A47);
const Color kCoral = Color(0xFFFF736A);
const Color kCoralStrong = Color(0xFFF94044);
const Color kInk = Color(0xFF1F2A37);
const Color kBg = Color(0xFFF6F7F9);
const Color kLine = Color(0xFFE4E7EC);

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kNavy,
    primary: kNavy,
    secondary: kCoral,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: kNavy,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kLine),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kCoral,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kCoral, width: 2),
      ),
    ),
  );
}
