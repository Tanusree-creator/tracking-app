import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../theme/app_theme.dart';
import '../l10n/l10n.dart';

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

/// The same Tamil solar month, in Tamil script.
String tamilMonthScript(DateTime d) {
  const script = {
    'Thai': 'தை', 'Maasi': 'மாசி', 'Panguni': 'பங்குனி', 'Chithirai': 'சித்திரை', 'Vaikasi': 'வைகாசி', 'Aani': 'ஆனி',
    'Aadi': 'ஆடி', 'Aavani': 'ஆவணி', 'Purattasi': 'புரட்டாசி', 'Aippasi': 'ஐப்பசி', 'Karthigai': 'கார்த்திகை', 'Margazhi': 'மார்கழி',
  };
  return script[tamilMonth(d)] ?? '';
}

/// Blue dashboard card: today's date, Tamil month and the next holiday. Tap to open the full calendar.
class TnCalendarCard extends StatelessWidget {
  final VoidCallback onTap;
  const TnCalendarCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final next = nextTnHoliday(now);
    final today = tnHolidayOn(now);
    final days = next?.date.difference(DateTime(now.year, now.month, now.day)).inDays;
    return GestureDetector(
      onTap: onTap,
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
              Text('Tamil Nadu calendar'.tr, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 2),
              Text('${tamilMonthScript(now)} · ${DateFormat('MMMM y').format(now)}', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              const SizedBox(height: 8),
              Text(
                today != null
                    ? trf('Today: {}', [today.name.tr])
                    : next == null
                        ? 'No holiday listed'.tr
                        : trf('Next: {} · {}', [next.name.tr, days == 1 ? 'tomorrow'.tr : trf('in {} days', [days])]),
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
