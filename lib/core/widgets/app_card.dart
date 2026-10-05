import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Standard surface: medium radius, soft shadow, consistent padding.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.md),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).cardTheme.color;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: Radii.medium,
        boxShadow: AppShadows.soft(context),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: Radii.medium,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
