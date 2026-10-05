import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const accent = Color(0xFF7C6CFF);
  static const bg = Color(0xFF0D1017);
  static const surface = Color(0xFF161B26);
  static const surfaceHigh = Color(0xFF1E2431);
  static const green = Color(0xFF2ED573);
  static const amber = Color(0xFFFFB020);
  static const red = Color(0xFFFF5C6C);
  static const muted = Color(0xFF8A93A6);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
    surface: AppColors.surface,
  ).copyWith(primary: AppColors.accent);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: Brightness.dark);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.bg, elevation: 0, scrolledUnderElevation: 0),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent.withValues(alpha: .25),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    splashFactory: InkSparkle.splashFactory,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
    ),
  );
}
