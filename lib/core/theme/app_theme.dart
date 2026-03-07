import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Modern Brand Colors
  static const Color primaryBlue = Color(0xFF0061FF); // Vibrant Electric Blue
  static const Color secondaryBlue = Color(0xFF60EFFF); // Cyan highlight
  static const Color darkBlue = Color(0xFF000D36); // Deep Navy
  static const Color alertRed = Color(0xFFFF3B30); // Modern Alert Red
  static const Color successGreen = Color(0xFF34C759); // Modern Success Green
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF2F6FF); // Very light blue-grey tint
  static const Color textDark = Color(0xFF1A1D26);
  static const Color textGrey = Color(0xFF6E717C);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: backgroundLight,
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: secondaryBlue,
        tertiary: alertRed,
        background: backgroundLight,
        surface: surfaceWhite,
        error: alertRed,
        brightness: Brightness.light,
      ),

      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: const TextStyle(
          color: textDark,
          fontWeight: FontWeight.w700,
          fontSize: 32,
          letterSpacing: -1.0,
        ),
        displayMedium: const TextStyle(
          color: textDark,
          fontWeight: FontWeight.w600,
          fontSize: 28,
          letterSpacing: -0.5,
        ),
        titleLarge: const TextStyle(
          color: textDark,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
        bodyLarge: const TextStyle(
          color: textDark,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: const TextStyle(
          color: textGrey,
          fontSize: 14,
        ),
        labelLarge: const TextStyle(
          color: surfaceWhite,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: backgroundLight,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        titleTextStyle: GoogleFonts.outfit(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: surfaceWhite,
          elevation: 4,
          shadowColor: primaryBlue.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0, // We will use custom shadows
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEEF2F6), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        hintStyle: TextStyle(color: textGrey.withOpacity(0.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: alertRed, width: 1),
        ),
      ),
      
      iconTheme: const IconThemeData(
        color: textDark,
        size: 24,
      ),
    );
  }
}
