import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../services/demo_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/month_attendance_calendar.dart';
import 'admin_dashboard_screen.dart' show dutyStyle;

class AdminEmployeeDetailScreen extends StatelessWidget {
  final Employee employee;
  const AdminEmployeeDetailScreen(this.employee, {super.key});

  @override
  Widget build(BuildContext context) {
    final e = employee;
    final now = DateTime.now();
    final month = DemoData.month(e.id, now);
    final hours = month.fold<double>(0, (a, d) => a + d.hours);
    final visits = month.fold<int>(0, (a, d) => a + DemoData.visitsDone(e.id, d.date));
    final km = month.fold<double>(0, (a, d) => a + DemoData.km(e.id, d.date));
    final recent = month.where((d) => d.hours > 0 && !d.date.isAfter(now)).toList().reversed.take(7).toList();
    final (label, color) = dutyStyle(e.status);

    return Scaffold(
      appBar: AppBar(title: Text(e.name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              CircleAvatar(radius: 30, backgroundColor: AppColors.accent, child: Text(e.initials, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text(e.email, style: const TextStyle(color: AppColors.muted)),
                  Text('${e.title} · ${e.district}', style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 8),
                  StatusChip(label, color),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        StatGrid([
          StatTile(icon: Icons.schedule, value: hours.toStringAsFixed(1), label: 'Hours (this month)'),
          StatTile(icon: Icons.task_alt, value: '$visits', label: 'Task Completion', color: AppColors.green),
          StatTile(icon: Icons.route, value: '${km.toStringAsFixed(0)} km', label: 'Distance Travelled', color: const Color(0xFF4FC3F7)),
          StatTile(icon: Icons.work_history, value: '${month.where((d) => d.hours > 0).length}', label: 'Shifts This Month', color: AppColors.amber),
        ]),
        const SectionTitle('Monthly Attendance'),
        Card(child: Padding(padding: const EdgeInsets.all(8), child: MonthAttendanceCalendar(daysFor: (m) => DemoData.month(e.id, m)))),
        const SectionTitle('Recent Shifts'),
        if (recent.isEmpty)
          const EmptyState(Icons.event_busy, 'No shift logged today.')
        else
          for (final d in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.work_outline, color: AppColors.accent),
                  title: Text(DateFormat('EEE, d MMM').format(d.date)),
                  subtitle: Text('${DemoData.visitsDone(e.id, d.date)} visits · ${DemoData.km(e.id, d.date)} km'),
                  trailing: Text('${d.hours} h', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
      ]),
    );
  }
}
