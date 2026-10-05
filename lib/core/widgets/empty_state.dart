import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_button.dart';

/// Centered icon + message + optional action, for empty and error screens.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: t.colorScheme.primary),
            const SizedBox(height: Space.md),
            Text(title,
                style: t.textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: Space.xs),
              Text(message!,
                  style: t.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: Space.xl),
              SizedBox(
                width: 200,
                child: AppButton(label: actionLabel!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
