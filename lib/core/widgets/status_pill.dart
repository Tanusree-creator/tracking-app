import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.sm, vertical: Space.xxs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: Radii.small,
        ),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      );
}
