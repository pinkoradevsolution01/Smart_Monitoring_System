import 'package:flutter/material.dart';

class AppColors {
  // Updated vibrant colors - Modern UI palette
  static const Color primaryBlue = Color(0xFF2563EB); // Vibrant blue
  static const Color darkBlue = Color(0xFF1E40AF); // Deep blue
  static const Color accentTeal = Color(0xFF06B6D4); // Teal accent
  static const Color successGreen = Color(0xFF10B981); // Success green
  static const Color warningOrange = Color(0xFFF59E0B); // Warning orange
  static const Color errorRed = Color(0xFFEF4444); // Error red
  static const Color black = Colors.black;
  static const Color white = Colors.white;
  static const Color lightGrey = Color(0xFFF3F4F6); // Light background
  static const Color darkGrey = Color(0xFF6B7280); // Text secondary
}

class AppTheme {
  static final ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primaryBlue,
    onPrimary: AppColors.white,
    secondary: AppColors.accentTeal,
    onSecondary: AppColors.white,
    tertiary: AppColors.successGreen,
    onTertiary: AppColors.white,
    surface: AppColors.white,
    onSurface: AppColors.black,
    error: AppColors.errorRed,
    onError: AppColors.white,
    outline: AppColors.darkGrey,
  );

  static final ThemeData light = ThemeData(
    colorScheme: _lightColorScheme,
    primaryColor: _lightColorScheme.primary,
    scaffoldBackgroundColor: AppColors.lightGrey,
    appBarTheme: AppBarTheme(
      backgroundColor: _lightColorScheme.primary,
      foregroundColor: _lightColorScheme.onPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightColorScheme.primary,
        foregroundColor: _lightColorScheme.onPrimary,
        minimumSize: Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      floatingLabelStyle: TextStyle(color: _lightColorScheme.primary),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _lightColorScheme.primary, width: 2),
      ),
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: _lightColorScheme.onSurface),
      bodyMedium: TextStyle(color: _lightColorScheme.onSurface),
      titleLarge: TextStyle(
        color: _lightColorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  // Returns a ThemeData using the provided primary MaterialColor.
  static ThemeData forPrimary(MaterialColor primaryColor) {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: primaryColor[700]!,
      onSecondary: Colors.white,
      tertiary: AppColors.successGreen,
      onTertiary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
      error: AppColors.errorRed,
      onError: Colors.white,
      outline: AppColors.darkGrey,
    );

    return ThemeData(
      colorScheme: colorScheme,
      primaryColor: colorScheme.primary,
      scaffoldBackgroundColor: AppColors.lightGrey,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        floatingLabelStyle: TextStyle(color: colorScheme.primary),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: colorScheme.onSurface),
        bodyMedium: TextStyle(color: colorScheme.onSurface),
        titleLarge: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
