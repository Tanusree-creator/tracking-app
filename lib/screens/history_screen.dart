import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/staff_provider.dart';
import '../services/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/month_attendance_calendar.dart';
import '../widgets/glass.dart';
import '../l10n/l10n.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<StaffProvider>(); // repaint when leave is approved
    final tr = context.watch<TrackingProvider>();
    final byDay = tr.hoursByDay;
    final now = DateTime.now();
    final monthShifts = tr.shifts.where((s) => s.start.year == now.year && s.start.month == now.month).toList();
    final totalH = tr.shifts.fold<double>(0, (a, s) => a + s.worked.inMinutes / 60);
    final avg = byDay.isEmpty ? 0.0 : totalH / byDay.length;
    final recent = tr.closedShifts.take(10).toList();
    final todayOpen = tr.openShift;

    return Scaffold(
      appBar: AppBar(title: Text('History & Attendance'.tr, style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: Sp.screen, children: [
        const SectionTitle('Monthly Attendance'),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: MonthAttendanceCalendar(
              isAbsent: (d) => context.read<StaffProvider>().approvedLeaveOn(d) != null,
              daysFor: (m) {
                final n = DateTime(m.year, m.month + 1, 0).day;
                return [
                  for (var i = 1; i <= n; i++)
                    AttendanceDay(DateTime(m.year, m.month, i), byDay[DateTime(m.year, m.month, i)] ?? 0),
                ];
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        StatGrid([
          StatTile(icon: Icons.work_history, value: '${tr.shifts.length}', label: 'Shifts Logged'.tr),
          StatTile(icon: Icons.schedule, value: totalH.toStringAsFixed(1), label: 'Total Hours Logged'.tr, color: AppColors.green),
          StatTile(icon: Icons.av_timer, value: avg.toStringAsFixed(1), label: 'Avg Hrs / Day'.tr, color: AppColors.amber),
          StatTile(icon: Icons.calendar_today, value: '${monthShifts.length}', label: 'This Month'.tr, color: const Color(0xFF4FC3F7)),
        ]),
        const SectionTitle('Recent Shifts'),
        if (todayOpen == null && recent.isEmpty)
          const EmptyState(Icons.event_busy, 'No shift logged today.')
        else ...[
          if (todayOpen != null) _ShiftTile(todayOpen, live: true),
          for (final s in recent) _ShiftTile(s),
        ],
      ]),
    );
  }
}

class _ShiftTile extends StatelessWidget {
  final Shift shift;
  final bool live;
  const _ShiftTile(this.shift, {this.live = false});

  @override
  Widget build(BuildContext context) {
    final t = DateFormat('h:mm a');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: AppColors.surfaceHigh, child: Icon(Icons.work_outline, color: AppColors.accent)),
          title: Text(DateFormat('EEE, d MMM').format(shift.start), style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${t.format(shift.start)} – ${live ? 'now'.tr : t.format(shift.end!)}  ·  ${shift.breaks.isEmpty ? 'No breaks'.tr : trCount(shift.breaks.length, 'break', 'breaks')}'),
          trailing: live ? const StatusChip('Live', AppColors.green) : Text(fmtDuration(shift.worked), style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
