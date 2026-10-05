import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/access_provider.dart';
import '../../services/app_notifications_provider.dart';
import '../../services/demo_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dark_tracking_map.dart';

(String, Color) dutyStyle(DutyStatus s) => switch (s) {
      DutyStatus.onDuty => ('On Duty', AppColors.green),
      DutyStatus.onBreak => ('On Break', AppColors.amber),
      DutyStatus.offDuty => ('Off', AppColors.muted),
    };

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final alerts = context.watch<AppNotificationsProvider>().forAudience(AlertAudience.admin);
    final emps = access.approved;
    final onDuty = emps.where((e) => e.status == DutyStatus.onDuty).toList();
    final districts = <String, List<Employee>>{};
    for (final e in emps) {
      districts.putIfAbsent(e.district, () => []).add(e);
    }
    final today = DateTime.now();
    final doneToday = emps.fold(0, (a, e) => a + DemoData.visitsDone(e.id, today));
    final doneMonth = emps.fold(0, (a, e) => a + DemoData.month(e.id, today).fold(0, (b, d) => b + DemoData.visitsDone(e.id, d.date)));

    return RefreshIndicator(
      onRefresh: access.refresh,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        StatGrid([
          StatTile(icon: Icons.engineering, value: '${onDuty.length}', label: 'Technicians On Duty', color: AppColors.green),
          StatTile(icon: Icons.groups, value: '${districts.entries.where((d) => d.value.any((e) => e.status == DutyStatus.onDuty)).length}', label: 'Active Teams'),
          StatTile(icon: Icons.assignment, value: '${doneMonth + emps.length * 2}', label: 'Total Jobs', color: AppColors.amber),
          StatTile(icon: Icons.task_alt, value: '$doneMonth', label: 'Completed Visits', color: const Color(0xFF4FC3F7)),
        ]),
        const SizedBox(height: 12),
        StatTile(icon: Icons.check_circle_outline, value: '$doneToday', label: 'Visits Done Today', color: AppColors.green),
        const SectionTitle('Live Field Deployment Map'),
        DarkTrackingMap(
          center: DemoData.center,
          zoom: 12,
          height: 280,
          markers: [
            for (final e in onDuty) MapMarker(DemoData.position(e), e.name),
            for (final e in emps.where((e) => e.status == DutyStatus.onBreak))
              MapMarker(DemoData.position(e), '${e.name} (break)', color: AppColors.amber),
          ],
        ),
        const SectionTitle('Team Activity'),
        for (final a in alerts.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.surfaceHigh, child: Icon(Icons.bolt, color: AppColors.accent)),
                title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(a.body),
                trailing: Text(DateFormat('h:mm a').format(a.time), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
            ),
          ),
        const SectionTitle('Active Team Status'),
        for (final d in districts.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 4),
            child: Text(d.key, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          ),
          Card(
            child: Column(children: [
              for (final e in d.value)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 16, backgroundColor: AppColors.surfaceHigh, child: Text(e.initials, style: const TextStyle(fontSize: 12))),
                  title: Text(e.name),
                  trailing: StatusChip(dutyStyle(e.status).$1, dutyStyle(e.status).$2),
                ),
            ]),
          ),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }
}
