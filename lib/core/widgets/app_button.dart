import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Full-width primary button with an animated loading state.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: destructive
          ? FilledButton.styleFrom(backgroundColor: scheme.error)
          : null,
      child: AnimatedSwitcher(
        duration: Motion.fast,
        child: loading
            ? const SizedBox(
                key: ValueKey('loading'),
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Row(
                key: const ValueKey('label'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: Space.xs),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}
