import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/app_notifications_provider.dart';
import '../theme/app_theme.dart';

/// Pinned to the top of a shell; shows the latest unread alert for [audience].
class StickyNotificationBanner extends StatelessWidget {
  final AlertAudience audience;
  const StickyNotificationBanner({super.key, required this.audience});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppNotificationsProvider>();
    final alert = provider.latestUnread(audience);
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: alert == null
          ? const SizedBox(width: double.infinity)
          : Material(
              color: AppColors.accent.withValues(alpha: .18),
              child: SafeArea(
                bottom: false,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.notifications_active, color: AppColors.accent),
                  title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(alert.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => provider.markRead(alert)),
                ),
              ),
            ),
    );
  }
}
