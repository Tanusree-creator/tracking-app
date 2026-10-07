import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'brand.dart';

/// Employees orbiting an operations centre, with a radar sweep. Tap a person to open them.
class RadarOrbit extends StatefulWidget {
  final List<Employee> employees;
  final ValueChanged<Employee> onTap;
  final double height;
  final Uint8List? Function(String id)? photoOf;
  const RadarOrbit({super.key, required this.employees, required this.onTap, this.photoOf, this.height = 380});

  @override
  State<RadarOrbit> createState() => _RadarOrbitState();
}

class _RadarOrbitState extends State<RadarOrbit> with TickerProviderStateMixin {
  late final _orbit = AnimationController(vsync: this, duration: const Duration(seconds: 90))..repeat();
  late final _sweep = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

  @override
  void dispose() {
    _orbit.dispose();
    _sweep.dispose();
    _intro.dispose();
    super.dispose();
  }

  Color _color(DutyStatus s) => switch (s) {
        DutyStatus.onDuty => AppColors.green,
        DutyStatus.onBreak => AppColors.amber,
        DutyStatus.offDuty => const Color(0xFF6B7A99),
      };

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: .35), blurRadius: 34, offset: const Offset(0, 12))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: .28), width: 1.2),
            gradient: RadialGradient(
              center: Alignment.center,
              radius: .95,
              colors: [AppColors.accent.withValues(alpha: .55), AppColors.blue800.withValues(alpha: .82), AppColors.blue900.withValues(alpha: .92)],
              stops: const [0, .6, 1],
            ),
          ),
          child: LayoutBuilder(builder: (_, c) {
            final size = Offset(c.maxWidth, c.maxHeight);
            final centre = size / 2;
            final maxR = math.min(c.maxWidth, c.maxHeight) / 2 - 30;
            final radii = [maxR * .38, maxR * .68, maxR * 1.0];
            final emps = widget.employees;
            return Stack(children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_sweep, _intro]),
                  builder: (_, _) => CustomPaint(painter: _RingsPainter(radii, _sweep.value, Curves.easeOut.transform(_intro.value))),
                ),
              ),
              Positioned(
                left: centre.dx - 40,
                top: centre.dy - 40,
                child: Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white.withValues(alpha: .32), Colors.white.withValues(alpha: .08)],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: .6), width: 1.5),
                    boxShadow: [BoxShadow(color: AppColors.blue400.withValues(alpha: .7), blurRadius: 28, spreadRadius: 2)],
                  ),
                  child: const BrandLogo(size: 52, white: true),
                ),
              ),
              if (emps.isEmpty)
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No approved employees yet', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              AnimatedBuilder(
                animation: Listenable.merge([_orbit, _intro]),
                builder: (_, _) {
                  final intro = Curves.easeOutCubic.transform(_intro.value);
                  return Stack(children: [
                    for (var i = 0; i < emps.length; i++)
                      () {
                        final ring = i % 3;
                        final perRing = (emps.length / 3).ceil().clamp(1, 99);
                        final idxInRing = i ~/ 3;
                        final dir = ring == 1 ? -1.0 : 1.0;
                        final speed = [3.0, 2.0, 1.0][ring];
                        final a = (idxInRing / perRing) * 2 * math.pi + ring * 1.1 + dir * _orbit.value * 2 * math.pi * speed;
                        final r = radii[ring] * intro;
                        final pos = centre + Offset(math.cos(a), math.sin(a)) * r;
                        final e = emps[i];
                        final col = _color(e.status);
                        final photo = widget.photoOf?.call(e.id);
                        return Positioned(
                          left: pos.dx - 25,
                          top: pos.dy - 25,
                          child: Opacity(
                            opacity: intro,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => widget.onTap(e),
                              child: SizedBox(
                                width: 50,
                                height: 50,
                                child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFEAF1FF),
                                      border: Border.all(color: col, width: 3),
                                      boxShadow: [BoxShadow(color: col.withValues(alpha: .6), blurRadius: 12)],
                                      image: photo == null ? null : DecorationImage(image: MemoryImage(photo), fit: BoxFit.cover),
                                    ),
                                    child: photo != null
                                        ? null
                                        : Text(e.initials, style: const TextStyle(color: AppColors.blue700, fontWeight: FontWeight.w800, fontSize: 14)),
                                  ),
                                  Positioned(
                                    top: -2,
                                    right: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(color: col, shape: BoxShape.circle, border: Border.all(color: AppColors.blue900, width: 2)),
                                    ),
                                  ),
                                  if (e.unread > 0)
                                    Positioned(
                                      bottom: -2,
                                      right: -2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                                        child: Text('${e.unread}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                ]),
                              ),
                            ),
                          ),
                        );
                      }(),
                  ]);
                },
              ),
              Positioned(
                left: 16,
                bottom: 12,
                child: Row(children: [
                  for (final (l, c) in [('Active', AppColors.green), ('Break', AppColors.amber), ('Off', const Color(0xFF6B7A99))]) ...[
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(width: 12),
                  ],
                ]),
              ),
            ]);
          }),
        ),
          ),
        ),
      );
}

class _RingsPainter extends CustomPainter {
  final List<double> radii;
  final double sweep;
  final double intro;
  _RingsPainter(this.radii, this.sweep, this.intro);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in radii) {
      canvas.drawCircle(c, r * intro, ring..color = Colors.white.withValues(alpha: .22));
    }
    // radar wedge
    final outer = radii.last * intro;
    final rect = Rect.fromCircle(center: c, radius: outer);
    final angle = sweep * 2 * math.pi;
    final shader = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: [AppColors.accent.withValues(alpha: 0), AppColors.accent.withValues(alpha: .0), AppColors.accent.withValues(alpha: .35)],
      stops: const [0, .78, 1],
      transform: GradientRotation(angle - math.pi * 2 * .0),
    ).createShader(rect);
    canvas.drawCircle(c, outer, Paint()..shader = shader);
    // leading edge line
    canvas.drawLine(c, c + Offset(math.cos(angle + math.pi * 2 - .0), math.sin(angle)) * outer,
        Paint()
          ..color = AppColors.accent.withValues(alpha: .5)
          ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_RingsPainter o) => o.sweep != sweep || o.intro != intro;
}
