import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass.dart';

/// Every pushed page gets its own copy of the glass background. Pages are transparent, so without this the
/// previous screen shows through while the new one slides in.
class _OpaquePage extends StatelessWidget {
  final Widget child;
  const _OpaquePage(this.child);

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.bg(Theme.of(context).brightness == Brightness.dark),
        child: Stack(children: [const Positioned.fill(child: GlassBackground()), child]),
      );
}

/// Screen change used everywhere: the new page slides in from the right over an opaque background while the
/// page underneath drifts left and dims a little (parallax), so the two never overlap messily.
Route<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => _OpaquePage(page),
      transitionsBuilder: (_, a, sa, child) {
        final inCurve = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        final outCurve = CurvedAnimation(parent: sa, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return SlideTransition(
          position: Tween(begin: Offset.zero, end: const Offset(-.22, 0)).animate(outCurve),
          child: FadeTransition(
            opacity: Tween(begin: 1.0, end: .55).animate(outCurve),
            child: SlideTransition(position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(inCurve), child: child),
          ),
        );
      },
    );

/// Used when the whole app changes (splash -> app, sign in -> app, sign out): a calm fade with a slight zoom.
Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => _OpaquePage(page),
      transitionsBuilder: (_, a, _, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: ScaleTransition(scale: Tween(begin: .97, end: 1.0).animate(c), child: child),
        );
      },
    );

/// Bottom-navigation pages. Every page stays alive (scroll position and loaded data are kept), and the page you
/// switch to fades and rises into place instead of popping in.
class AnimatedTabStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const AnimatedTabStack({super.key, required this.index, required this.children});

  @override
  State<AnimatedTabStack> createState() => _AnimatedTabStackState();
}

class _AnimatedTabStackState extends State<AnimatedTabStack> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280), value: 1);
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  final _built = <int>{};

  @override
  void initState() {
    super.initState();
    _built.add(widget.index);
  }

  @override
  void didUpdateWidget(AnimatedTabStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _built.add(widget.index);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        for (var i = 0; i < widget.children.length; i++)
          if (_built.contains(i)) // pages are created the first time they are opened
            Offstage(
              offstage: i != widget.index,
              child: TickerMode(
                enabled: i == widget.index,
                child: i == widget.index
                    ? FadeTransition(
                        opacity: _curve,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, .025), end: Offset.zero).animate(_curve),
                          child: widget.children[i],
                        ),
                      )
                    : widget.children[i],
              ),
            ),
      ]);
}

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
