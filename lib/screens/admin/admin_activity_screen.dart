import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/app_notifications_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../l10n/l10n.dart';

/// Dashboard widget: latest event and how many are new. Tap to open the full list.
class RecentActivityCard extends StatelessWidget {
  final VoidCallback onTap;
  const RecentActivityCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<AppNotificationsProvider>().forAudience(AlertAudience.admin);
    final fresh = alerts.where((a) => !a.read).length;
    final last = alerts.isEmpty ? null : alerts.first;
    return GlassCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Sp.l),
        child: Row(children: [
          Badge(
            isLabelVisible: fresh > 0,
            label: Text('$fresh'),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: .15), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.bolt, color: AppColors.accent, size: 26),
            ),
          ),
          const SizedBox(width: Sp.l),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Recent activity'.tr, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 2),
              Text(last == null ? 'Shifts, tasks and messages appear here'.tr : last.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ]),
      ),
    );
  }
}

class AdminActivityScreen extends StatelessWidget {
  const AdminActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<AppNotificationsProvider>().forAudience(AlertAudience.admin);
    return Scaffold(
      appBar: AppBar(title: Text('Recent activity'.tr, style: TextStyle(fontWeight: FontWeight.w800))),
      body: alerts.isEmpty
          ? const EmptyState(Icons.bolt_outlined, 'Shifts, tasks and messages will show up here as they happen.')
          : ListView.separated(
              padding: Sp.screen,
              itemCount: alerts.length,
              separatorBuilder: (_, _) => const SizedBox(height: Sp.s),
              itemBuilder: (_, i) {
                final a = alerts[i];
                return GlassCard(
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: AppColors.surfaceHigh, child: Icon(Icons.bolt, color: AppColors.accent)),
                    title: Text(a.title.tr, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(a.body.tr),
                    trailing: Text(DateFormat('d MMM\nh:mm a').format(a.time), textAlign: TextAlign.end, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ),
                );
              },
            ),
    );
  }
}
