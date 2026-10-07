import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/api.dart';

import '../theme/app_theme.dart';
import 'common.dart';
import 'glass.dart';

/// A Tamil Nadu public holiday. [approx] = depends on moon sighting / panchangam, so it can shift by a day.
class TnHoliday {
  final DateTime date;
  final String name;
  final bool approx;
  const TnHoliday(this.date, this.name, {this.approx = false});
}

/// Fixed-date holidays repeat every year; the rest are listed per year.
/// Moon-based dates are marked [approx]: confirm against the year's Tamil Nadu Government order.
List<TnHoliday> tnHolidays(int y) {
  TnHoliday h(int m, int d, String n, {bool approx = false}) => TnHoliday(DateTime(y, m, d), n, approx: approx);
  return [
    h(1, 1, "New Year's Day"),
    ...switch (y) {
      2026 => [
          h(1, 15, 'Thai Pongal'),
          h(1, 16, 'Thiruvalluvar Day'),
          h(1, 17, 'Uzhavar Thirunal'),
          h(2, 1, 'Thai Poosam', approx: true),
          h(3, 19, 'Telugu New Year', approx: true),
          h(3, 21, 'Ramzan', approx: true),
          h(3, 31, 'Mahavir Jayanthi', approx: true),
          h(4, 3, 'Good Friday'),
          h(5, 27, 'Bakrid', approx: true),
          h(6, 26, 'Muharram', approx: true),
          h(8, 26, 'Milad-un-Nabi', approx: true),
          h(9, 4, 'Krishna Jayanthi', approx: true),
          h(9, 14, 'Vinayagar Chathurthi', approx: true),
          h(10, 19, 'Ayudha Pooja', approx: true),
          h(10, 20, 'Vijayadasami', approx: true),
          h(11, 8, 'Deepavali', approx: true),
        ],
      // 2027-2029: planning dates from the usual calendars; all moon-based ones are approximate.
      2027 => [
          h(1, 15, 'Thai Pongal', approx: true),
          h(1, 16, 'Thiruvalluvar Day', approx: true),
          h(1, 17, 'Uzhavar Thirunal', approx: true),
          h(3, 10, 'Ramzan', approx: true),
          h(3, 26, 'Good Friday'),
          h(5, 17, 'Bakrid', approx: true),
          h(6, 16, 'Muharram', approx: true),
          h(8, 15, 'Milad-un-Nabi', approx: true),
          h(9, 4, 'Vinayagar Chathurthi', approx: true),
          h(10, 18, 'Ayudha Pooja', approx: true),
          h(10, 19, 'Vijayadasami', approx: true),
          h(10, 29, 'Deepavali', approx: true),
        ],
      2028 => [
          h(1, 15, 'Thai Pongal', approx: true),
          h(1, 16, 'Thiruvalluvar Day', approx: true),
          h(1, 17, 'Uzhavar Thirunal', approx: true),
          h(2, 26, 'Ramzan', approx: true),
          h(4, 14, 'Good Friday'),
          h(5, 5, 'Bakrid', approx: true),
          h(6, 4, 'Muharram', approx: true),
          h(8, 3, 'Milad-un-Nabi', approx: true),
          h(8, 25, 'Vinayagar Chathurthi', approx: true),
          h(10, 5, 'Ayudha Pooja', approx: true),
          h(10, 6, 'Vijayadasami', approx: true),
          h(10, 17, 'Deepavali', approx: true),
        ],
      2029 => [
          h(1, 14, 'Thai Pongal', approx: true),
          h(1, 15, 'Thiruvalluvar Day', approx: true),
          h(1, 16, 'Uzhavar Thirunal', approx: true),
          h(2, 14, 'Ramzan', approx: true),
          h(3, 30, 'Good Friday'),
          h(4, 24, 'Bakrid', approx: true),
          h(5, 24, 'Muharram', approx: true),
          h(7, 24, 'Milad-un-Nabi', approx: true),
          h(10, 24, 'Ayudha Pooja', approx: true),
          h(10, 25, 'Vijayadasami', approx: true),
          h(11, 5, 'Deepavali', approx: true),
        ],
      _ => <TnHoliday>[],
    },
    h(1, 26, 'Republic Day'),
    h(4, 14, 'Tamil New Year · Dr. Ambedkar Jayanthi'),
    h(5, 1, 'May Day'),
    h(8, 15, 'Independence Day'),
    h(10, 2, 'Gandhi Jayanthi'),
    h(12, 25, 'Christmas'),
  ]..sort((a, b) => a.date.compareTo(b.date));
}

TnHoliday? tnHolidayOn(DateTime d) {
  for (final h in tnHolidays(d.year)) {
    if (isSameDay(h.date, d)) return h;
  }
  return null;
}

/// Next holiday on or after [from], looking into next year if needed.
TnHoliday? nextTnHoliday(DateTime from) {
  final day = DateTime(from.year, from.month, from.day);
  for (final y in [from.year, from.year + 1]) {
    for (final h in tnHolidays(y)) {
      if (!h.date.isBefore(day)) return h;
    }
  }
  return null;
}

/// Tamil solar month (approximate: the Sun enters each rasi on about these dates).
String tamilMonth(DateTime d) {
  const names = ['Thai', 'Maasi', 'Panguni', 'Chithirai', 'Vaikasi', 'Aani', 'Aadi', 'Aavani', 'Purattasi', 'Aippasi', 'Karthigai', 'Margazhi'];
  const startDay = [14, 13, 14, 14, 15, 15, 17, 17, 17, 18, 17, 16]; // starting Jan, in calendar-month order
  final m = d.month - 1;
  final i = d.day >= startDay[m] ? m : (m + 11) % 12;
  return names[i];
}

/// Blue dashboard card: today's date, Tamil month and the next holiday. Tap to open the full calendar.
class TnCalendarCard extends StatelessWidget {
  const TnCalendarCard({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final next = nextTnHoliday(now);
    final today = tnHolidayOn(now);
    final days = next?.date.difference(DateTime(now.year, now.month, now.day)).inDays;
    return GestureDetector(
      onTap: () => showTnCalendar(context),
      child: Container(
        padding: const EdgeInsets.all(Sp.l),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.blue600, AppColors.accent, AppColors.blue400]),
          border: Border.all(color: Colors.white.withValues(alpha: .45)),
          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: .4), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Row(children: [
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .5))),
            child: Column(children: [
              Text(DateFormat('MMM').format(now).toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1)),
              Text('${now.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 32, height: 1.1)),
              Text(DateFormat('EEE').format(now), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: Sp.l),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tamil Nadu calendar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 2),
              Text('${tamilMonth(now)} month · ${DateFormat('MMMM y').format(now)}', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              const SizedBox(height: 8),
              Text(
                today != null
                    ? 'Today: ${today.name}'
                    : next == null
                        ? 'No holiday listed'
                        : 'Next: ${next.name} · ${days == 1 ? 'tomorrow' : 'in $days days'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ]),
      ),
    );
  }
}

void showTnCalendar(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _TnCalendarSheet(),
    );

class _TnCalendarSheet extends StatefulWidget {
  const _TnCalendarSheet();

  @override
  State<_TnCalendarSheet> createState() => _TnCalendarSheetState();
}

class _TnCalendarSheetState extends State<_TnCalendarSheet> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  Map<DateTime, List<Map<String, dynamic>>> _tasks = {};

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Tasks of every employee for the visible month (plus the grey days around it).
  Future<void> _loadTasks() async {
    final from = DateTime(_focused.year, _focused.month - 1, 20);
    final to = DateTime(_focused.year, _focused.month + 1, 12);
    try {
      final rows = await Api.adminTasksRange(from, to);
      final byDay = <DateTime, List<Map<String, dynamic>>>{};
      for (final r in rows) {
        final at = DateTime.parse(r['scheduled_time'] as String).toLocal();
        byDay.putIfAbsent(_day(at), () => []).add(r);
      }
      if (mounted) setState(() => _tasks = {..._tasks, ...byDay});
    } catch (_) {} // 005_profile_photo_map.sql not run yet: holidays only
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final monthHolidays = tnHolidays(_focused.year).where((h) => h.date.month == _focused.month).toList();
    final picked = tnHolidayOn(_selected);
    final ink = dark ? Colors.white : AppColors.blue800;
    BoxDecoration dot(Color c, {bool outline = false}) => BoxDecoration(
        shape: BoxShape.circle, color: outline ? null : c, border: outline ? Border.all(color: c, width: 1.6) : null);
    return ListView(padding: const EdgeInsets.fromLTRB(Sp.l, 0, Sp.l, Sp.xl), children: [
      Row(children: [
        Expanded(child: Text('Tamil Nadu calendar', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.accent))),
        TextButton(onPressed: () => setState(() => _focused = _selected = DateTime.now()), child: const Text('Today')),
      ]),
      Text('${tamilMonth(_focused)} month (Tamil)', style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: Sp.s),
      GlassCard(
        padding: const EdgeInsets.all(Sp.s),
        child: TableCalendar(
          firstDay: DateTime(2024),
          lastDay: DateTime(2029, 12, 31),
          focusedDay: _focused,
          selectedDayPredicate: (d) => isSameDay(d, _selected),
          holidayPredicate: (d) => tnHolidayOn(d) != null,
          onDaySelected: (s, f) => setState(() {
            _selected = s;
            _focused = f;
          }),
          onPageChanged: (f) {
            setState(() => _focused = f);
            _loadTasks();
          },
          eventLoader: (d) => _tasks[_day(d)] ?? const [],
          calendarBuilders: CalendarBuilders(markerBuilder: (_, day, events) {
            if (events.isEmpty) return null;
            final open = events.any((e) => (e as Map)['status'] != 'completed');
            return Positioned(
              bottom: 3,
              child: Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: open ? AppColors.amber : AppColors.green)),
            );
          }),
          startingDayOfWeek: StartingDayOfWeek.sunday,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
            leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.accent),
            rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.accent),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12),
            weekendStyle: const TextStyle(color: AppColors.blue400, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          calendarStyle: CalendarStyle(
            defaultTextStyle: TextStyle(color: ink),
            weekendTextStyle: const TextStyle(color: AppColors.blue400, fontWeight: FontWeight.w600),
            outsideTextStyle: const TextStyle(color: AppColors.muted),
            todayDecoration: dot(AppColors.accent, outline: true),
            todayTextStyle: TextStyle(color: ink, fontWeight: FontWeight.w800),
            selectedDecoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.blue600, AppColors.blue400])),
            selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            holidayDecoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: .18), border: Border.all(color: AppColors.accent.withValues(alpha: .6))),
            holidayTextStyle: TextStyle(color: dark ? AppColors.blue200 : AppColors.blue700, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      const SizedBox(height: Sp.m),
      if (picked != null)
        _HolidayTile(picked, highlighted: true)
      else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.s),
          child: Text('${DateFormat('EEEE, d MMMM').format(_selected)} · ${tamilMonth(_selected)} · no holiday', style: const TextStyle(color: AppColors.muted)),
        ),
      ..._dayTasks(),
      const SizedBox(height: Sp.s),
      Text('Holidays in ${DateFormat('MMMM y').format(_focused)}', style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: Sp.s),
      if (monthHolidays.isEmpty)
        const Text('No public holidays this month.', style: TextStyle(color: AppColors.muted))
      else
        for (final h in monthHolidays) _HolidayTile(h),
      const SizedBox(height: Sp.m),
      const Text(
        'Dates marked ≈ follow the moon or the panchangam and can move by a day. Confirm with the official Tamil Nadu Government holiday list.',
        style: TextStyle(color: AppColors.muted, fontSize: 11.5),
      ),
    ]);
  }
}

extension on _TnCalendarSheetState {
  /// Tasks on the selected day. Amber dot = still open, green = closed (admin was notified when it closed).
  List<Widget> _dayTasks() {
    final list = _tasks[_day(_selected)] ?? const <Map<String, dynamic>>[];
    if (list.isEmpty) return const [];
    return [
      const SizedBox(height: Sp.s),
      Text('Tasks on ${DateFormat('d MMM').format(_selected)}', style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: Sp.s),
      for (final t in list)
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.s),
          child: GlassCard(
            child: ListTile(
              dense: true,
              leading: Icon(t['status'] == 'completed' ? Icons.check_circle : Icons.schedule,
                  color: t['status'] == 'completed' ? AppColors.green : AppColors.amber),
              title: Text(t['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${t['user_name']} · ${DateFormat('h:mm a').format(DateTime.parse(t['scheduled_time'] as String).toLocal())}'),
              trailing: StatusChip(t['status'] == 'completed' ? 'Closed' : (t['status'] == 'inProgress' ? 'In progress' : 'Open'),
                  t['status'] == 'completed' ? AppColors.green : AppColors.amber),
            ),
          ),
        ),
    ];
  }
}

class _HolidayTile extends StatelessWidget {
  final TnHoliday h;
  final bool highlighted;
  const _HolidayTile(this.h, {this.highlighted = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Sp.s),
        child: GlassCard(
          borderColor: highlighted ? AppColors.accent : null,
          child: ListTile(
            dense: true,
            leading: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
              child: Text('${h.date.day}', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${DateFormat('EEEE, d MMM').format(h.date)}${h.approx ? '  ≈' : ''}'),
          ),
        ),
      );
}
