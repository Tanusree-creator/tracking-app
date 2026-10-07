import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../services/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/outcome_sheet.dart';
import 'location_picker_screen.dart';
import 'route_map_screen.dart';

/// "Books ordered · 25 copies"
String outcomeText(Visit v) => v.outcome == null ? '' : '${v.outcome!.label}${v.copies == null ? '' : ' · ${v.copies} copies'}';

(String, Color, IconData) visitStatusStyle(VisitStatus s) => switch (s) {
      VisitStatus.pending => ('Pending', AppColors.amber, Icons.schedule),
      VisitStatus.inProgress => ('In Progress', AppColors.accent, Icons.play_arrow_rounded),
      VisitStatus.completed => ('Completed', AppColors.green, Icons.check_circle),
    };

class VisitCard extends StatelessWidget {
  final Visit visit;
  const VisitCard(this.visit, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = visitStatusStyle(visit.status);
    final t = Theme.of(context).textTheme;
    final active = visit.status == VisitStatus.inProgress;
    return GlassCard(
      borderColor: active ? AppColors.accent : null,
      borderWidth: active ? 1.6 : 1,
      onTap: () => Navigator.of(context).push(slideRoute(VisitDetailScreen(visit.id))),
      child: Padding(
          padding: const EdgeInsets.all(Sp.l),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 56,
              child: Column(children: [
                Text(DateFormat('h:mm').format(visit.scheduledTime), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text(DateFormat('a').format(visit.scheduledTime), style: t.bodySmall?.copyWith(color: AppColors.muted)),
              ]),
            ),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(visit.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: Sp.xs),
                Text(visit.location, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: AppColors.muted)),
                const SizedBox(height: Sp.s),
                StatusChip(label, color, icon: icon),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ]),
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
        for (final (i, v) in list.indexed) Padding(padding: const EdgeInsets.only(bottom: Sp.m), child: VisitCard(v).enter(i)),
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks', style: TextStyle(fontWeight: FontWeight.w700))),
      // lifted above the floating nav bar
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: FloatingActionButton.extended(
          onPressed: () => showAddVisitSheet(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Task'),
        ),
      ),
      body: visits.isEmpty
          ? const EmptyState(Icons.event_busy, 'No tasks yet. Add one, or wait for your admin to assign one.')
          : ListView(padding: const EdgeInsets.fromLTRB(Sp.l, 0, Sp.l, 96), children: [
              group('In Progress', VisitStatus.inProgress),
              group('Pending', VisitStatus.pending),
              group('Completed', VisitStatus.completed),
            ]),
    );
  }
}

void showAddVisitSheet(BuildContext context) {
  final title = TextEditingController();
  PickedPlace? place;
  TimeOfDay? time;
  final form = GlobalKey<FormState>();
  final tr = context.read<TrackingProvider>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('New Task', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            GlowTextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a title' : null,
            ),
            const SizedBox(height: 12),
            LocationField(start: tr.current, initial: place, onPicked: (p) => place = p),
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
                tr.addVisit(title.text.trim(), place!.name, DateTime(n.year, n.month, n.day, time!.hour, time!.minute),
                    lat: place!.lat, lng: place!.lng);
                Navigator.pop(ctx);
              },
              child: const Text('Add Task'),
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
    final (label, color, icon) = visitStatusStyle(v.status);
    final f = DateFormat('h:mm a');
    Widget row(IconData i, String k, String val) => ListTile(
          leading: Icon(i, color: AppColors.muted),
          title: Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          subtitle: Text(val, style: const TextStyle(fontSize: 16)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Task Detail')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(v.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: StatusChip(label, color, icon: icon)),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(children: [
            row(Icons.place_outlined, 'Location', v.location),
            row(Icons.schedule, 'Scheduled', f.format(v.scheduledTime)),
            if (v.startedAt != null) row(Icons.play_arrow, 'Started', f.format(v.startedAt!)),
            if (v.completedAt != null) row(Icons.check_circle_outline, 'Completed', f.format(v.completedAt!)),
            if (v.outcome != null) row(v.outcome!.icon, 'Result', outcomeText(v)),
            if (v.outcomeNote != null) row(Icons.notes, 'Note', v.outcomeNote!),
          ]),
        ),
        const SizedBox(height: 24),
        if (v.status == VisitStatus.pending)
          FilledButton.icon(
            onPressed: () {
              if (!tr.clockedIn) {
                snack(context, 'Clock in from Home before starting a visit.');
                return;
              }
              tr.startVisit(v);
              snack(context, 'Visit started');
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Visit'),
          ),
        if (v.status == VisitStatus.inProgress)
          FilledButton.icon(
            onPressed: () => _complete(context, tr, v),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Take photo & complete'),
          ),
        if (v.status == VisitStatus.inProgress)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('A photo of the visited place is required to close this task.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
        if (v.photoB64 != null) ...[
          const SectionTitle('Photo of the place'),
          ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(base64Decode(v.photoB64!), fit: BoxFit.cover)),
        ],
        if (v.status != VisitStatus.pending && v.startedAt != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(slideRoute(RouteMapScreen(
              title: v.title,
              from: v.startedAt!,
              to: v.completedAt ?? DateTime.now(),
              live: v.status == VisitStatus.inProgress,
              load: Api.myRoute,
              destination: v.lat == null ? null : LatLng(v.lat!, v.lng!),
              visits: [v],
            ))),
            icon: const Icon(Icons.route),
            label: const Text('View route taken'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ]),
    );
  }
}

/// Opens the camera; the visit is only completed once a photo exists.
Future<void> _complete(BuildContext context, TrackingProvider tr, Visit v) async {
  try {
    final shot = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 70);
    if (shot == null) {
      if (context.mounted) toast(context, 'A photo is required to complete the task', type: ToastType.info);
      return;
    }
    final Uint8List bytes = await shot.readAsBytes();
    if (!context.mounted) return;
    final result = await askVisitOutcome(context);
    if (result == null) {
      if (context.mounted) toast(context, 'Pick how the visit went to close the task', type: ToastType.info);
      return;
    }
    await tr.completeVisit(v, base64Encode(bytes), outcome: result.outcome, note: result.note, copies: result.copies);
    if (context.mounted) toast(context, 'Task completed. Your admin has been notified.', type: ToastType.success);
  } catch (_) {
    if (context.mounted) toast(context, 'Could not open the camera. Allow camera access and try again.', type: ToastType.error);
  }
}
