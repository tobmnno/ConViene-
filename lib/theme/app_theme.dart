import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const blue = Color(0xFF175CD3);
  static const deepBlue = Color(0xFF102A56);
  static const green = Color(0xFF16B364);
  static const softBlue = Color(0xFFEAF2FF);
  static const background = Color(0xFFF7F9FC);
  static const textGray = Color(0xFF667085);
  static const line = Color(0xFFE4EAF2);
  static const white = Color(0xFFFFFFFF);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary: AppColors.blue,
      secondary: AppColors.green,
      surface: AppColors.white,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Manrope',
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'Manrope',
      bodyColor: AppColors.deepBlue,
      displayColor: AppColors.deepBlue,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.deepBlue,
      titleTextStyle: TextStyle(
        color: AppColors.deepBlue,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        fontFamily: 'Manrope',
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: AppColors.blue,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontFamily: 'Manrope',
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: AppColors.deepBlue,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontFamily: 'Manrope',
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      hintStyle: const TextStyle(color: AppColors.textGray),
      prefixIconColor: AppColors.deepBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.blue, width: 1.4),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.blue,
      unselectedItemColor: AppColors.deepBlue,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      unselectedLabelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      backgroundColor: AppColors.white,
      elevation: 0,
    ),
  );
}
