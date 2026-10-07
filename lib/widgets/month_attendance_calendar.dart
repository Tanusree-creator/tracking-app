import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class MonthAttendanceCalendar extends StatefulWidget {
  /// Provide hours for a given month; called when the visible month changes.
  final List<AttendanceDay> Function(DateTime month) daysFor;

  /// Days on approved leave: shown as absent.
  final bool Function(DateTime day)? isAbsent;
  const MonthAttendanceCalendar({super.key, required this.daysFor, this.isAbsent});

  @override
  State<MonthAttendanceCalendar> createState() => _MonthAttendanceCalendarState();
}

class _MonthAttendanceCalendarState extends State<MonthAttendanceCalendar> {
  DateTime _focused = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final d in widget.daysFor(_focused)) d.date.day: d};
    Widget cell(DateTime day, {bool today = false}) {
      final a = day.month == _focused.month ? byDay[day.day] : null;
      final absent = day.month == _focused.month && (widget.isAbsent?.call(day) ?? false);
      final color = absent
          ? AppColors.red
          : a == null || a.hours == 0
              ? null
              : (a.isFull ? AppColors.green : AppColors.amber);
      return Center(
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color?.withValues(alpha: absent ? .3 : .22),
            shape: BoxShape.circle,
            border: today ? Border.all(color: AppColors.accent, width: 2) : null,
          ),
          child: Text('${day.day}', style: TextStyle(color: color ?? AppColors.muted, fontWeight: FontWeight.w600)),
        ),
      );
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 4, children: [
          _Dot(AppColors.green, 'Full day'.tr),
          _Dot(AppColors.amber, 'Partial'.tr),
          _Dot(AppColors.red, 'Absent (leave)'.tr),
          _Dot(AppColors.muted, 'No shift'.tr),
        ]),
      ),
      TableCalendar(
        firstDay: DateTime(2023),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focused,
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (_, day, _) => cell(day),
          todayBuilder: (_, day, _) => cell(day, today: true),
          outsideBuilder: (_, day, _) => Center(child: Text('${day.day}', style: TextStyle(color: AppColors.muted.withValues(alpha: .4)))),
        ),
        onPageChanged: (d) => setState(() => _focused = d),
      ),
    ]);
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot(this.color, this.label);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ]);
}
