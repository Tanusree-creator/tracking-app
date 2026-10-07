import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/office_models.dart';

/// Icon that suits a holiday by name (falls back to a celebration icon).
IconData holidayIcon(String name) {
  final n = name.toLowerCase();
  const table = <String, IconData>{
    'pongal': Icons.rice_bowl,
    'uzhavar': Icons.agriculture,
    'valluvar': Icons.menu_book,
    'poosam': Icons.temple_hindu,
    'new year': Icons.celebration,
    'ramzan': Icons.mosque,
    'bakrid': Icons.mosque,
    'muharram': Icons.mosque,
    'milad': Icons.mosque,
    'good friday': Icons.church,
    'christmas': Icons.park,
    'mahavir': Icons.self_improvement,
    'krishna': Icons.temple_hindu,
    'vinayagar': Icons.temple_hindu,
    'ayudha': Icons.build_circle,
    'vijayadasami': Icons.auto_stories,
    'deepavali': Icons.local_fire_department,
    'republic': Icons.flag,
    'independence': Icons.flag,
    'gandhi': Icons.diversity_3,
    'may day': Icons.engineering,
    'ambedkar': Icons.balance,
  };
  for (final e in table.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return Icons.celebration;
}

IconData iconFor(DayItem i) => i.kind == DayKind.holiday ? holidayIcon(i.title) : i.kind.icon;

/// A picture for a calendar entry: a coloured burst of rays with the entry's icon on a frosted disc.
/// Used large as a day banner and small as a list thumbnail.
class EventPicture extends StatelessWidget {
  final DayItem item;
  final double? width;
  final double height;
  final double radius;
  final Widget? overlay;
  const EventPicture(this.item, {super.key, this.width, required this.height, this.radius = 16, this.overlay});

  @override
  Widget build(BuildContext context) {
    final base = Color(item.kind.argb);
    final dark = HSLColor.fromColor(base).withLightness((HSLColor.fromColor(base).lightness * .55).clamp(.12, .5)).toColor();
    final light = HSLColor.fromColor(base).withLightness((HSLColor.fromColor(base).lightness * 1.18).clamp(0, .72)).toColor();
    final disc = height * (overlay == null ? .5 : .46);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [light, base, dark])),
          ),
          CustomPaint(painter: _RayPainter(Colors.white.withValues(alpha: .13))),
          Align(
            alignment: overlay == null ? Alignment.center : const Alignment(0, -.35),
            child: Container(
              width: disc,
              height: disc,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .2),
                border: Border.all(color: Colors.white.withValues(alpha: .45), width: height > 80 ? 1.6 : 1),
              ),
              child: Icon(iconFor(item), color: Colors.white, size: disc * .52),
            ),
          ),
          ?overlay,
        ]),
      ),
    );
  }
}

class _RayPainter extends CustomPainter {
  final Color color;
  _RayPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.longestSide;
    const rays = 16;
    final p = Paint()..color = color;
    for (var i = 0; i < rays; i += 2) {
      final a0 = i * 2 * math.pi / rays;
      final a1 = (i + 1) * 2 * math.pi / rays;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + r * math.cos(a0), c.dy + r * math.sin(a0))
          ..lineTo(c.dx + r * math.cos(a1), c.dy + r * math.sin(a1))
          ..close(),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_RayPainter o) => o.color != color;
}
