import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Page background: a soft blue gradient with a few blurred colour pools, so frosted glass has something to refract.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    Widget pool(Color c, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)])),
        );
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [Color(0xFF060F2B), Color(0xFF0A1740), Color(0xFF070D1F)]
                : const [Color(0xFFEAF2FF), Color(0xFFF6F9FF), Color(0xFFE3EDFF)],
          ),
        ),
        child: Stack(children: [
          Positioned(top: -90, left: -80, child: pool(AppColors.accent.withValues(alpha: dark ? .35 : .28), 340)),
          Positioned(top: 260, right: -140, child: pool(AppColors.blue400.withValues(alpha: dark ? .22 : .30), 380)),
          Positioned(bottom: -120, left: -60, child: pool(AppColors.blue600.withValues(alpha: dark ? .28 : .20), 360)),
        ]),
      ),
    );
  }
}

/// Frosted-glass surface: blur + translucent fill + a bright top-left edge. Used by cards and bars.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final Color? tint;
  final Color? borderColor;
  final double borderWidth;
  final bool glow;
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 20,
    this.blur = 18,
    this.tint,
    this.borderColor,
    this.borderWidth = 1,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final r = BorderRadius.circular(radius);
    final fill = tint ?? (dark ? Colors.white.withValues(alpha: .07) : Colors.white.withValues(alpha: .62));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: glow ? AppColors.accent.withValues(alpha: dark ? .35 : .25) : Colors.black.withValues(alpha: dark ? .30 : .07),
            blurRadius: glow ? 26 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [fill, fill.withValues(alpha: fill.a * .55)],
              ),
              border: Border.all(
                color: borderColor ?? (dark ? Colors.white.withValues(alpha: .16) : Colors.white.withValues(alpha: .9)),
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Glass card. Name kept so existing screens keep working.
/// [clipBehavior] and [shape] are accepted for drop-in compatibility and ignored.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final double radius;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;
  final Color? tint;
  final Clip clipBehavior;
  final ShapeBorder? shape;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.blur = 18,
    this.radius = 20,
    this.onTap,
    this.borderColor,
    this.borderWidth = 1,
    this.tint,
    this.clipBehavior = Clip.none,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    Widget body = padding == null ? child : Padding(padding: padding!, child: child);
    return GlassSurface(
      radius: radius,
      blur: blur == 0 ? 18 : blur,
      tint: tint,
      borderColor: borderColor,
      borderWidth: borderWidth,
      glow: borderColor == AppColors.accent,
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null ? body : InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: body),
      ),
    );
  }
}

class GlassNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
  const GlassNavItem(this.icon, this.selectedIcon, this.label, {this.badge = 0});
}

/// Floating frosted bottom bar. The selected tab sits in a highlighted pill. Pair with `extendBody: true`.
class GlassBottomNav extends StatelessWidget {
  final List<GlassNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  const GlassBottomNav({super.key, required this.items, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: GlassSurface(
          radius: 30,
          blur: 24,
          tint: dark ? Colors.white.withValues(alpha: .09) : Colors.white.withValues(alpha: .66),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(children: [
              for (final (i, it) in items.indexed)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: i == index
                            ? LinearGradient(colors: [AppColors.accent.withValues(alpha: dark ? .45 : .22), AppColors.blue400.withValues(alpha: dark ? .25 : .12)])
                            : null,
                        border: i == index ? Border.all(color: AppColors.blue400.withValues(alpha: dark ? .6 : .45)) : null,
                        boxShadow: i == index ? [BoxShadow(color: AppColors.accent.withValues(alpha: .28), blurRadius: 14)] : null,
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Badge(
                          isLabelVisible: it.badge > 0,
                          label: Text('${it.badge}'),
                          child: Icon(i == index ? it.selectedIcon : it.icon,
                              size: 24, color: i == index ? (dark ? Colors.white : AppColors.blue700) : AppColors.muted),
                        ),
                        const SizedBox(height: 3),
                        Text(it.label.tr,
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: i == index ? FontWeight.w800 : FontWeight.w600,
                                color: i == index ? (dark ? Colors.white : AppColors.blue700) : AppColors.muted)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Frosted background for an AppBar's `flexibleSpace`.
class GlassBarSpace extends StatelessWidget {
  const GlassBarSpace({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark ? Colors.white.withValues(alpha: .05) : Colors.white.withValues(alpha: .55),
            border: Border(bottom: BorderSide(color: dark ? Colors.white.withValues(alpha: .12) : Colors.white.withValues(alpha: .9))),
          ),
        ),
      ),
    );
  }
}

/// Plain text field (kept under the old name so call sites don't change).
class GlowTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final InputDecoration? decoration;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final bool? enabled;
  final int? maxLines;

  const GlowTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.decoration,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.enabled,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        initialValue: initialValue,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        decoration: decoration,
        validator: validator,
        onFieldSubmitted: onFieldSubmitted,
        onChanged: onChanged,
        obscureText: obscureText,
        textCapitalization: textCapitalization,
        enabled: enabled,
        maxLines: obscureText ? 1 : maxLines,
      );
}

/// Staggered entrance: fade + slight rise, delayed by list position.
extension GlassMotion on Widget {
  Widget enter([int index = 0]) => animate()
      .fadeIn(duration: 380.ms, delay: (55 * index.clamp(0, 10)).ms)
      .slideY(begin: .08, end: 0, duration: 380.ms, delay: (55 * index.clamp(0, 10)).ms, curve: Curves.easeOutCubic);
}
