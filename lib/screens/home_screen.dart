import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/access_provider.dart';
import '../services/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'tasks_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = context.watch<TrackingProvider>();
    final me = context.watch<AccessProvider>().me!;
    final (label, color) = !tr.clockedIn
        ? ('Not Clocked In', AppColors.muted)
        : tr.onBreak
            ? ('On Break', AppColors.amber)
            : ('Clocked In', AppColors.green);
    final visits = tr.todaysVisits;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hi, ${me.name.split(' ').first}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr.clockedIn ? 'Clock Out' : 'Clock In',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(tr.clockedIn ? 'Toggle off to end your shift' : 'Toggle on to start your shift',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ]),
                ),
                Switch(value: tr.clockedIn, onChanged: (_) => tr.toggleShift()),
              ]),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: StatusChip(label, color)),
              const Divider(height: 28),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Break', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      tr.clockedIn ? 'Toggle on when you take a break' : 'Clock in from Home to enable breaks',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ]),
                ),
                Switch(value: tr.onBreak, onChanged: tr.clockedIn ? (_) => tr.toggleBreak() : null),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        StatGrid([
          StatTile(icon: Icons.timer_outlined, value: fmtDuration(tr.hoursToday), label: 'Hours Worked Today'),
          StatTile(icon: Icons.place_outlined, value: '${tr.visitsCompleted}', label: 'Visits Completed', color: AppColors.green),
          StatTile(icon: Icons.task_alt, value: '${tr.jobsFinishedToday}', label: 'Jobs Finished Today', color: AppColors.amber),
          StatTile(icon: Icons.route_outlined, value: '${tr.distanceTodayKm.toStringAsFixed(1)} km', label: 'Distance Today', color: const Color(0xFF4FC3F7)),
        ]),
        const SectionTitle("Today's Visits"),
        if (visits.isEmpty)
          const EmptyState(Icons.event_busy, 'No visits added yet.')
        else
          for (final v in visits) Padding(padding: const EdgeInsets.only(bottom: 10), child: VisitCard(v)),
      ]),
    );
  }
}
