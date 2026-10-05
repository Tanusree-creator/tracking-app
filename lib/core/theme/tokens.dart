import 'package:flutter/material.dart';

/// Spacing scale. Use these everywhere, never a raw number.
abstract final class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  static const screen = EdgeInsets.all(md);
}

/// Border radius scale: small / medium / large.
abstract final class Radii {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;

  static final small = BorderRadius.circular(sm);
  static final medium = BorderRadius.circular(md);
  static final large = BorderRadius.circular(lg);
}

/// Type scale: headline 28, title 22, subtitle 18, body 16, caption 13.
abstract final class FontSizes {
  static const double headline = 28;
  static const double title = 22;
  static const double subtitle = 18;
  static const double body = 16;
  static const double caption = 13;
}

abstract final class AppShadows {
  /// Soft, low-opacity, wide blur. Skipped in dark mode where it can't be seen.
  static List<BoxShadow> soft(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const []
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ];
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 280);
  static const curve = Curves.easeOutCubic;
}
