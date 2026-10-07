import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/calendar_loaders.dart';
import '../services/staff_provider.dart';
import '../services/tracking_provider.dart';
import '../widgets/anim.dart';
import 'calendar_screen.dart';

/// The calendar as a bottom-nav tab.
class StaffCalendarTab extends StatelessWidget {
  const StaffCalendarTab({super.key});

  @override
  Widget build(BuildContext context) => CalendarScreen(embedded: true, loader: _loader(context));
}

CalendarLoader _loader(BuildContext context) {
  final sp = context.read<StaffProvider>();
  final tr = context.read<TrackingProvider>();
  return (from, to) async {
    await sp.refresh(silent: true);
    return myCalendarItems(visits: tr.visits, tasks: sp.tasks, followUps: sp.followUps, leaves: sp.leaves, from: from, to: to);
  };
}

/// Employee calendar: holidays plus my own visits, tasks, calls and leave.
void openStaffCalendar(BuildContext context) {
  Navigator.of(context).push(slideRoute(CalendarScreen(loader: _loader(context))));
}
