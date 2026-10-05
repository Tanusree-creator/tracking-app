import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// One primary colour, one accent, neutral surfaces.
class AppTheme {
  static const primary = Color(0xFF2563EB);
  static const accent = Color(0xFF14B8A6);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: b)
        .copyWith(tertiary: accent);

    final background = dark ? const Color(0xFF0E1116) : const Color(0xFFF6F7FB);
    final surface = dark ? const Color(0xFF171B22) : Colors.white;
    final onSurface = dark ? const Color(0xFFE6E8EC) : const Color(0xFF111827);
    final muted = dark ? const Color(0xFF9AA3B2) : const Color(0xFF6B7280);

    TextStyle s(double size, FontWeight w, Color c) =>
        TextStyle(fontSize: size, fontWeight: w, color: c, height: 1.35);

    final text = GoogleFonts.interTextTheme(TextTheme(
      headlineMedium: s(FontSizes.headline, FontWeight.w700, onSurface),
      titleLarge: s(FontSizes.title, FontWeight.w700, onSurface),
      titleMedium: s(FontSizes.subtitle, FontWeight.w600, onSurface),
      bodyLarge: s(FontSizes.body, FontWeight.w400, onSurface),
      bodyMedium: s(FontSizes.body, FontWeight.w400, onSurface),
      labelLarge: s(FontSizes.body, FontWeight.w600, onSurface),
      bodySmall: s(FontSizes.caption, FontWeight.w400, muted),
      labelSmall: s(FontSizes.caption, FontWeight.w500, muted),
    ));

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme.copyWith(surface: surface, onSurface: onSurface),
      scaffoldBackgroundColor: background,
      textTheme: text,
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Radii.medium),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      dividerTheme: DividerThemeData(
        color: dark ? const Color(0xFF262C36) : const Color(0xFFE5E7EB),
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1E232C) : const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Space.md, vertical: Space.md),
        labelStyle: text.bodyMedium?.copyWith(color: muted),
        border: OutlineInputBorder(
            borderRadius: Radii.medium, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.medium,
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.medium,
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.medium,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: Radii.medium),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: Radii.small),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: Radii.medium),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: Radii.large),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: Radii.small),
      ),
    );
  }
}
