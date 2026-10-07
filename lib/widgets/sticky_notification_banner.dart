import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/app_notifications_provider.dart';
import '../theme/app_theme.dart';
import 'glass.dart';

/// Pinned to the top of a shell; shows the latest unread alert for [audience]
/// and dismisses itself after a few seconds.
class StickyNotificationBanner extends StatefulWidget {
  final AlertAudience audience;
  const StickyNotificationBanner({super.key, required this.audience});

  @override
  State<StickyNotificationBanner> createState() => _StickyNotificationBannerState();
}

class _StickyNotificationBannerState extends State<StickyNotificationBanner> {
  Timer? _timer;
  String? _timerFor;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppNotificationsProvider>();
    final alert = provider.latestUnread(widget.audience);
    if (alert != null && alert.id != _timerFor) {
      _timerFor = alert.id;
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 4), () {
        if (mounted) provider.markRead(alert);
      });
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: alert == null
          ? const SizedBox(width: double.infinity)
          : SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: GlassCard(
                  blur: 18,
                  borderColor: AppColors.accent.withValues(alpha: .5),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.notifications_active_rounded, color: AppColors.accent),
                    title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(alert.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => provider.markRead(alert)),
                  ),
                ).animate(key: ValueKey(alert.id)).slideY(begin: -.4, end: 0, duration: 300.ms, curve: Curves.easeOutCubic).fadeIn(duration: 300.ms),
              ),
            ),
    );
  }
}
