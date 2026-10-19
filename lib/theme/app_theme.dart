import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static bool _dark = false;

  static void setDarkMode(bool dark) => _dark = dark;

  static bool get isDark => _dark;

  static const blue = Color(0xFF175CD3);
  static const navy = Color(0xFF102A56);
  static const green = Color(0xFF16B364);
  static const white = Color(0xFFFFFFFF);

  static Color get accentBlue => _dark ? const Color(0xFF8CB9FF) : blue;
  static Color get deepBlue => _dark ? const Color(0xFFF0F5FF) : navy;
  static Color get softBlue =>
      _dark ? const Color(0xFF1A2C46) : const Color(0xFFEAF2FF);
  static Color get background =>
      _dark ? const Color(0xFF0C1420) : const Color(0xFFF7F9FC);
  static Color get surface => _dark ? const Color(0xFF172233) : white;
  static Color get textGray =>
      _dark ? const Color(0xFFAFBDD0) : const Color(0xFF667085);
  static Color get line =>
      _dark ? const Color(0xFF34445A) : const Color(0xFFE4EAF2);
  static Color get successSurface =>
      _dark ? const Color(0xFF143328) : const Color(0xFFEAF8F0);
  static Color get successBorder =>
      _dark ? const Color(0xFF275D44) : const Color(0xFFC7EFD8);
  static Color get warningSurface =>
      _dark ? const Color(0xFF332A1B) : const Color(0xFFFFF8E6);
  static Color get warningBorder =>
      _dark ? const Color(0xFF735329) : const Color(0xFFFFE7B3);
  static Color get errorSurface =>
      _dark ? const Color(0xFF352322) : const Color(0xFFFFF4ED);
  static Color get greenText => _dark ? const Color(0xFF5CE29A) : green;
  static Color get warningText =>
      _dark ? const Color(0xFFF2C66D) : const Color(0xFF8A5A00);
  static Color get errorText =>
      _dark ? const Color(0xFFFF9D84) : const Color(0xFFB54708);
}

ThemeData buildAppTheme({bool dark = false}) {
  AppColors.setDarkMode(dark);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: AppColors.accentBlue,
      secondary: AppColors.green,
      surface: AppColors.surface,
      onSurface: AppColors.deepBlue,
      onPrimary: dark ? AppColors.navy : AppColors.white,
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
    appBarTheme: AppBarTheme(
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
        side: BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontFamily: 'Manrope',
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: TextStyle(color: AppColors.textGray),
      prefixIconColor: AppColors.deepBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.accentBlue, width: 1.4),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.accentBlue,
      unselectedItemColor: AppColors.deepBlue,
      selectedLabelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      backgroundColor: AppColors.surface,
      elevation: 0,
    ),
  );
}
