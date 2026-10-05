import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

(String, Color) visitStatusStyle(VisitStatus s) => switch (s) {
      VisitStatus.pending => ('Pending', AppColors.amber),
      VisitStatus.inProgress => ('In Progress', AppColors.accent),
      VisitStatus.completed => ('Completed', AppColors.green),
    };

class VisitCard extends StatelessWidget {
  final Visit visit;
  const VisitCard(this.visit, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color) = visitStatusStyle(visit.status);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VisitDetailScreen(visit.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Column(children: [
              Text(DateFormat('h:mm').format(visit.scheduledTime), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(DateFormat('a').format(visit.scheduledTime), style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(visit.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.place, size: 14, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(visit.location, style: const TextStyle(color: AppColors.muted, fontSize: 13), overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            ),
            StatusChip(label, color),
          ]),
        ),
      ),
    );
  }
}

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final visits = context.watch<TrackingProvider>().visits;
    Widget group(String title, VisitStatus s) {
      final list = visits.where((v) => v.status == s).toList();
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(title),
        for (final v in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: VisitCard(v)),
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks', style: TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddVisitSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Visit'),
      ),
      body: visits.isEmpty
          ? const EmptyState(Icons.event_busy, 'No visits added yet.')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
              group('In Progress', VisitStatus.inProgress),
              group('Pending', VisitStatus.pending),
              group('Completed', VisitStatus.completed),
            ]),
    );
  }
}

void showAddVisitSheet(BuildContext context) {
  final title = TextEditingController();
  final location = TextEditingController();
  TimeOfDay? time;
  final form = GlobalKey<FormState>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('New Visit', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextFormField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a title' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: location,
              decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.place_outlined)),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a location' : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                if (t != null) setState(() => time = t);
              },
              icon: const Icon(Icons.schedule),
              label: Text(time == null ? 'Select time' : time!.format(ctx)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                if (time == null) {
                  snack(ctx, 'Select a time for the visit');
                  return;
                }
                final n = DateTime.now();
                context.read<TrackingProvider>().addVisit(
                    title.text.trim(), location.text.trim(), DateTime(n.year, n.month, n.day, time!.hour, time!.minute));
                Navigator.pop(ctx);
              },
              child: const Text('Add Visit'),
            ),
          ]),
        ),
      ),
    ),
  );
}

class VisitDetailScreen extends StatelessWidget {
  final String visitId;
  const VisitDetailScreen(this.visitId, {super.key});

  @override
  Widget build(BuildContext context) {
    final tr = context.watch<TrackingProvider>();
    final v = tr.visits.firstWhere((e) => e.id == visitId);
    final (label, color) = visitStatusStyle(v.status);
    final f = DateFormat('h:mm a');
    Widget row(IconData i, String k, String val) => ListTile(
          leading: Icon(i, color: AppColors.muted),
          title: Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          subtitle: Text(val, style: const TextStyle(fontSize: 16)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Visit Detail')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(v.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: StatusChip(label, color)),
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            row(Icons.place_outlined, 'Location', v.location),
            row(Icons.schedule, 'Scheduled', f.format(v.scheduledTime)),
            if (v.startedAt != null) row(Icons.play_arrow, 'Started', f.format(v.startedAt!)),
            if (v.completedAt != null) row(Icons.check_circle_outline, 'Completed', f.format(v.completedAt!)),
          ]),
        ),
        const SizedBox(height: 24),
        if (v.status == VisitStatus.pending)
          FilledButton.icon(onPressed: () => tr.startVisit(v), icon: const Icon(Icons.play_arrow), label: const Text('Start Visit')),
        if (v.status == VisitStatus.inProgress)
          FilledButton.icon(onPressed: () => tr.completeVisit(v), icon: const Icon(Icons.check), label: const Text('Mark Completed')),
      ]),
    );
  }
}
