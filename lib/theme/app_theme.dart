import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One blue family for the whole app. Green/amber/red are kept only for status meaning.
class AppColors {
  static const blue900 = Color(0xFF060F2B);
  static const blue800 = Color(0xFF0B1E4F);
  static const blue700 = Color(0xFF0B3DB8);
  static const blue600 = Color(0xFF1257E0);
  static const accent = Color(0xFF1D6FFF); // primary blue
  static const blue400 = Color(0xFF5B97FF);
  static const blue200 = Color(0xFFBBD3FF);
  static const blue50 = Color(0xFFEEF4FF);
  static const green = Color(0xFF1FAF63);
  static const amber = Color(0xFFE59A00);
  static const red = Color(0xFFE5484D);
  static const muted = Color(0xFF7D8BA8);
  // Translucent so it reads as a subtle fill on both light and dark cards.
  static const surfaceHigh = Color(0x1F5B97FF);

  static Color bg(bool dark) => dark ? const Color(0xFF070D1F) : const Color(0xFFF2F6FE);
  static Color card(bool dark) => dark ? const Color(0xFF0E1834) : Colors.white;
  static Color edge(bool dark) => dark ? const Color(0xFF1B2A55) : const Color(0xFFDCE6FA);
}

/// One spacing scale for the whole app.
class Sp {
  static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 24.0;
  static const screen = EdgeInsets.fromLTRB(l, s, l, 120); // clears the floating nav bar
}

ThemeData buildTheme(Brightness b) {
  final light = b == Brightness.light;
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: b).copyWith(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    secondary: AppColors.blue600,
    surface: AppColors.card(!light),
    surfaceTint: Colors.transparent,
    outlineVariant: AppColors.edge(!light),
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: b);
  final surface = AppColors.card(!light);
  final glassFill = light ? Colors.white.withValues(alpha: .7) : Colors.white.withValues(alpha: .07);
  final glassEdge = AppColors.edge(!light);
  OutlineInputBorder field(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent, // GlassBackground sits behind the navigator
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: glassEdge)),
    ),
    textTheme: GoogleFonts.manropeTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shadowColor: Colors.black12,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: AppColors.accent.withValues(alpha: .2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: glassFill,
      border: field(glassEdge),
      enabledBorder: field(glassEdge),
      focusedBorder: field(AppColors.accent, 1.6),
      errorBorder: field(AppColors.red),
      focusedErrorBorder: field(AppColors.red, 1.6),
      disabledBorder: field(glassEdge.withValues(alpha: .4)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    splashFactory: InkSparkle.splashFactory,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
  );
}
