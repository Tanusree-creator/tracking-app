import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Horizontal slide used for screen changes (like the swipe panels in the reference).
Route<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, sa, child) {
        final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: Tween(begin: .6, end: 1.0).animate(curved), child: child),
        );
      },
    );

/// Number that counts up to [value] whenever it changes.
class CountUp extends StatelessWidget {
  final double value;
  final int decimals;
  final String suffix;
  final TextStyle? style;
  const CountUp(this.value, {super.key, this.decimals = 0, this.suffix = '', this.style});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => Text('${v.toStringAsFixed(decimals)}$suffix', style: style),
      );
}

/// Ring that fills to [value] (0..1) with an animated sweep.
class DonutProgress extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Widget? center;
  final Color? color;
  const DonutProgress({super.key, required this.value, this.size = 120, this.stroke = 12, this.center, this.color});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(v, stroke, color ?? AppColors.accent, dark ? AppColors.blue800 : AppColors.blue50),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double v, stroke;
  final Color color, track;
  _DonutPainter(this.v, this.stroke, this.color, this.track);

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(s.width - stroke, s.height - stroke);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v, false, p..color = color);
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.v != v || o.color != color || o.track != track;
}

/// Thin vertical bar chart cell that grows from zero.
class GrowBar extends StatelessWidget {
  final double fraction;
  final double width;
  final double height;
  final Color color;
  const GrowBar({super.key, required this.fraction, required this.height, this.width = 14, this.color = AppColors.accent});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: fraction.clamp(0, 1)),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (_, f, _) => Container(
          width: width,
          height: math.max(4, height * f),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(width / 2)),
        ),
      );
}
