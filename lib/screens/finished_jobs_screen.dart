import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'route_map_screen.dart';
import '../l10n/l10n.dart';

/// Jobs finished today. Tapping one opens the route walked between its start and finish.
class FinishedJobsScreen extends StatelessWidget {
  const FinishedJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final jobs = context.watch<TrackingProvider>().finishedToday;
    final t = DateFormat('h:mm a');
    return Scaffold(
      appBar: AppBar(title: Text('Jobs finished today'.tr)),
      body: jobs.isEmpty
          ? const EmptyState(Icons.task_alt, 'No jobs finished yet')
          : ListView.separated(
              padding: const EdgeInsets.all(Sp.l),
              itemCount: jobs.length,
              separatorBuilder: (_, _) => const SizedBox(height: Sp.m),
              itemBuilder: (_, i) {
                final v = jobs[i];
                final from = v.startedAt ?? v.scheduledTime;
                return GlassCard(
                  onTap: () => Navigator.of(context).push(slideRoute(RouteMapScreen(
                    title: v.title,
                    from: from,
                    to: v.completedAt ?? DateTime.now(),
                    load: Api.myRoute,
                    destination: v.lat == null ? null : LatLng(v.lat!, v.lng!),
                    visits: [v],
                  ))),
                  child: ListTile(
                    leading: const Icon(Icons.check_circle, color: AppColors.green),
                    title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${v.location}\n${t.format(from)} – ${t.format(v.completedAt!)}', maxLines: 3, overflow: TextOverflow.ellipsis),
                    isThreeLine: true,
                    trailing: const Icon(Icons.map_outlined, color: AppColors.accent),
                  ),
                ).enter(i);
              },
            ),
    );
  }
}
