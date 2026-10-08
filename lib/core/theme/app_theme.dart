import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF080A0D);
  static const surface = Color(0xFF11151A);
  static const raised = Color(0xFF1B2027);
  static const border = Color(0xFF2A3039);
  static const muted = Color(0xFFABB3BF);
  static const flame = Color(0xFFFF673B);
  static const green = Color(0xFFB2EE87);
  static const purple = Color(0xFF9C83F6);
  static const blue = Color(0xFF6CB8F4);
  static const text = Color(0xFFF5F6F8);
}

ThemeData buildTheme() => ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.flame,
    onPrimary: AppColors.background,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    secondary: AppColors.green,
  ),
  fontFamily: 'Manrope',
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
    ),
    headlineMedium: TextStyle(
      fontSize: 27,
      fontWeight: FontWeight.w800,
      letterSpacing: -.8,
    ),
    titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
  ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
  dividerColor: AppColors.border,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    contentPadding: const EdgeInsets.all(18),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 56),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 52),
      foregroundColor: AppColors.text,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    surfaceTintColor: Colors.transparent,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.surface,
    indicatorColor: AppColors.flame.withValues(alpha: .15),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (s) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: s.contains(WidgetState.selected)
            ? AppColors.flame
            : AppColors.muted,
      ),
    ),
  ),
);
