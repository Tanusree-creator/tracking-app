import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/access_provider.dart';
import '../../services/api.dart';
import '../../services/tracking_provider.dart' show fmtDuration;
import '../../theme/app_theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/month_attendance_calendar.dart';
import '../chat_screens.dart';
import '../location_picker_screen.dart';
import '../route_map_screen.dart';

(String, Color, IconData) dutyStyle(DutyStatus s) => switch (s) {
      DutyStatus.onDuty => ('On Duty', AppColors.green, Icons.check_circle),
      DutyStatus.onBreak => ('On Break', AppColors.amber, Icons.free_breakfast),
      DutyStatus.offDuty => ('Off', AppColors.muted, Icons.power_settings_new),
    };

/// Everything about one employee: overview, visits, attendance and the routes they took.
class AdminEmployeeDetailScreen extends StatefulWidget {
  final Employee employee;
  const AdminEmployeeDetailScreen(this.employee, {super.key});

  @override
  State<AdminEmployeeDetailScreen> createState() => _AdminEmployeeDetailScreenState();
}

class _AdminEmployeeDetailScreenState extends State<AdminEmployeeDetailScreen> {
  List<Shift> _shifts = [];
  List<Visit> _visits = [];
  List<Map<String, dynamic>> _faces = [];
  bool _loading = true;
  String? _error;

  Employee get e => widget.employee;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.adminEmployeeData(e.id);
      if (!mounted) return;
      setState(() {
        _shifts = (d['shifts'] as List).map((s) => Shift.fromRemote(Map<String, dynamic>.from(s as Map))).toList();
        _visits = (d['visits'] as List).map((v) => Visit.fromRemote(Map<String, dynamic>.from(v as Map))).toList();
        _faces = List<Map<String, dynamic>>.from(d['faces'] as List);
        _loading = false;
        _error = null;
      });
    } catch (err) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '${err.toString().replaceFirst('Exception: ', '')}\n(Run supabase/004_field_sync.sql if you have not yet.)';
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _route(DateTime from, DateTime to) => Api.adminRoute(e.id, from, to);

  /// Route map for this employee: task locations in the window (plus any still open) show as pins.
  Widget _routeScreen(String title, DateTime from, DateTime to, {bool live = false}) => RouteMapScreen(
        title: title,
        from: from,
        to: to,
        live: live,
        load: _route,
        visits: [for (final v in _visits) if (v.status != VisitStatus.completed || (!v.scheduledTime.isBefore(from) && v.scheduledTime.isBefore(to))) v],
        personName: e.name,
        personInitials: e.initials,
        personPhoto: context.read<AccessProvider>().avatarOf(e.id),
      );

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = dutyStyle(e.status);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(e.name),
          actions: [
            IconButton(
              tooltip: 'Message',
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => Navigator.of(context).push(slideRoute(AdminChatThreadScreen(e.id, e.name))),
            ),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              UserAvatar(photo: context.watch<AccessProvider>().avatarOf(e.id), initials: e.initials, radius: 30, ring: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.email, style: const TextStyle(color: AppColors.muted), overflow: TextOverflow.ellipsis),
                  Text('${e.title} · ${e.district}', style: const TextStyle(color: AppColors.muted)),
                  if (e.phone != null) Text(e.phone!, style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 6),
                  StatusChip(label, color, icon: icon),
                ]),
              ),
              FilledButton.icon(
                onPressed: () => _assignTask(context),
                icon: const Icon(Icons.add_task, size: 18),
                label: const Text('Task'),
                style: FilledButton.styleFrom(minimumSize: const Size(90, 42)),
              ),
            ]),
          ),
          const TabBar(isScrollable: false, tabs: [Tab(text: 'Overview'), Tab(text: 'Visits'), Tab(text: 'Attendance'), Tab(text: 'Routes')]),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorState(_error!, _load)
                    : TabBarView(children: [_overview(context), _visitsTab(context), _attendanceTab(context), _routesTab(context)]),
          ),
        ]),
      ),
    );
  }

  // ── tabs ───────────────────────────────────────────────────────────────────
  Widget _overview(BuildContext context) {
    final now = DateTime.now();
    final monthShifts = _shifts.where((s) => s.start.year == now.year && s.start.month == now.month).toList();
    final hours = monthShifts.fold<double>(0, (a, s) => a + s.worked.inMinutes / 60);
    final done = _visits.where((v) => v.status == VisitStatus.completed).length;
    final today = DateTime(now.year, now.month, now.day);
    final f = DateFormat('d MMM, h:mm a');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: Sp.screen, children: [
        StatGrid([
          StatTile(icon: Icons.schedule, value: hours.toStringAsFixed(1), label: 'Hours this month'),
          StatTile(icon: Icons.task_alt, value: '$done / ${_visits.length}', label: 'Tasks completed', color: AppColors.green),
          StatTile(icon: Icons.work_history, value: '${monthShifts.length}', label: 'Shifts this month', color: AppColors.blue400),
          StatTile(
            icon: Icons.route,
            value: 'Live',
            label: e.status == DutyStatus.offDuty ? 'Today’s route' : 'Track now',
            color: AppColors.amber,
            onTap: () => Navigator.of(context).push(
                slideRoute(_routeScreen("${e.name.split(' ').first}'s route today", today, today.add(const Duration(days: 1)), live: true))),
          ),
        ]),
        const SectionTitle('Face verification log'),
        if (_faces.isEmpty)
          const EmptyState(Icons.face_retouching_off, 'No face checks recorded yet.')
        else
          for (final c in _faces.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                child: ListTile(
                  leading: const Icon(Icons.face, color: AppColors.accent),
                  title: Text(switch (c['kind']) {
                    'enroll' => 'Reference photo saved',
                    'sign_in' => 'Verified at sign-in',
                    'clock_in' => 'Verified at clock-in',
                    _ => 'Verified after break',
                  }),
                  subtitle: Text(f.format(DateTime.parse(c['at'] as String).toLocal())),
                  trailing: const Icon(Icons.image_outlined, color: AppColors.muted),
                  onTap: () => _showPhoto(context, 'Face check', () => Api.adminFacePhoto(c['id'] as String)),
                ),
              ),
            ),
      ]),
    );
  }

  Widget _visitsTab(BuildContext context) {
    if (_visits.isEmpty) return const EmptyState(Icons.event_busy, 'No visits yet.');
    final f = DateFormat('EEE d MMM · h:mm a');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: Sp.screen,
        itemCount: _visits.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final v = _visits[i];
          final (label, color, icon) = switch (v.status) {
            VisitStatus.pending => ('Pending', AppColors.amber, Icons.schedule),
            VisitStatus.inProgress => ('In Progress', AppColors.accent, Icons.play_arrow_rounded),
            VisitStatus.completed => ('Completed', AppColors.green, Icons.check_circle),
          };
          return GlassCard(
            onTap: () => Navigator.of(context).push(slideRoute(_VisitDetail(v, e, _route))),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(v.title, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  StatusChip(label, color, icon: icon),
                ]),
                const SizedBox(height: 6),
                Text(v.location, style: const TextStyle(color: AppColors.muted, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(f.format(v.scheduledTime), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                if (v.startedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      const Icon(Icons.route, size: 16, color: AppColors.accent),
                      const SizedBox(width: 6),
                      RouteKmText(load: _route, from: v.startedAt!, to: v.completedAt ?? DateTime.now()),
                      const Spacer(),
                      if (v.hasPhoto) const Icon(Icons.photo_camera_outlined, size: 16, color: AppColors.muted),
                    ]),
                  ),
              ]),
            ),
          ).enter(i);
        },
      ),
    );
  }

  Widget _attendanceTab(BuildContext context) {
    final byDay = <DateTime, double>{};
    for (final s in _shifts) {
      final d = DateTime(s.start.year, s.start.month, s.start.day);
      byDay[d] = (byDay[d] ?? 0) + s.worked.inMinutes / 60;
    }
    final t = DateFormat('h:mm a');
    return ListView(padding: Sp.screen, children: [
      GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: MonthAttendanceCalendar(
            daysFor: (m) => [
              for (var i = 1; i <= DateTime(m.year, m.month + 1, 0).day; i++)
                AttendanceDay(DateTime(m.year, m.month, i), byDay[DateTime(m.year, m.month, i)] ?? 0),
            ],
          ),
        ),
      ),
      const SectionTitle('Shifts'),
      if (_shifts.isEmpty)
        const EmptyState(Icons.event_busy, 'No shifts logged.')
      else
        for (final s in _shifts.take(30))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              child: ListTile(
                leading: const Icon(Icons.work_outline, color: AppColors.accent),
                title: Text(DateFormat('EEE, d MMM').format(s.start)),
                subtitle: Text('${t.format(s.start)} – ${s.isOpen ? 'now' : t.format(s.end!)} · ${s.breaks.length} break${s.breaks.length == 1 ? '' : 's'}'),
                trailing: s.isOpen ? const StatusChip('Live', AppColors.green) : Text(fmtDuration(s.worked), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
    ]);
  }

  Widget _routesTab(BuildContext context) {
    final days = <DateTime, List<Shift>>{};
    for (final s in _shifts) {
      days.putIfAbsent(DateTime(s.start.year, s.start.month, s.start.day), () => []).add(s);
    }
    final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
    if (keys.isEmpty) return const EmptyState(Icons.route_outlined, 'No routes yet. Routes appear once a shift is tracked.');
    return ListView.separated(
      padding: Sp.screen,
      itemCount: keys.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final d = keys[i];
        final end = d.add(const Duration(days: 1));
        final hrs = days[d]!.fold<double>(0, (a, s) => a + s.worked.inMinutes / 60);
        return GlassCard(
          onTap: () => Navigator.of(context).push(
              slideRoute(_routeScreen(DateFormat('EEE, d MMM y').format(d), d, end))),
          child: ListTile(
            leading: const Icon(Icons.map_outlined, color: AppColors.accent),
            title: Text(DateFormat('EEEE, d MMM y').format(d)),
            subtitle: Text('${hrs.toStringAsFixed(1)} h worked'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              RouteKmText(load: _route, from: d, to: end),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ]),
          ),
        ).enter(i);
      },
    );
  }

  // ── actions ────────────────────────────────────────────────────────────────
  void _assignTask(BuildContext context) {
    final title = TextEditingController();
    final form = GlobalKey<FormState>();
    PickedPlace? place;
    DateTime when = DateTime.now().add(const Duration(hours: 1));
    bool busy = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Assign task to ${e.name.split(' ').first}', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              GlowTextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Task title'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              LocationField(onPicked: (p) => place = p),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(context: ctx, initialDate: when, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (d == null || !ctx.mounted) return;
                  final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(when));
                  if (t == null) return;
                  setS(() => when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                },
                icon: const Icon(Icons.schedule),
                label: Text(DateFormat('EEE d MMM · h:mm a').format(when)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setS(() => busy = true);
                        try {
                          await Api.adminCreateTask(e.id, title.text, place!.name, place!.lat, place!.lng, when);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) toast(context, 'Task created and sent to ${e.name.split(' ').first}', type: ToastType.success);
                          _load();
                        } catch (err) {
                          setS(() => busy = false);
                          if (ctx.mounted) toast(ctx, err.toString().replaceFirst('Exception: ', ''), type: ToastType.error);
                        }
                      },
                child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create task'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

Future<void> _showPhoto(BuildContext context, String title, Future<String?> Function() load) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<String?>(
        future: load(),
        builder: (_, s) {
          if (s.connectionState != ConnectionState.done) {
            return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
          }
          if (s.data == null) {
            return const SizedBox(height: 160, child: Center(child: Text('No photo available')));
          }
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Image.memory(base64Decode(s.data!), fit: BoxFit.cover),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ]);
        },
      ),
    ),
  );
}

class _VisitDetail extends StatelessWidget {
  final Visit v;
  final Employee e;
  final RouteLoader load;
  const _VisitDetail(this.v, this.e, this.load);

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('EEE d MMM y, h:mm a');
    Widget row(IconData i, String k, String val) => ListTile(
          leading: Icon(i, color: AppColors.muted),
          title: Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          subtitle: Text(val, style: const TextStyle(fontSize: 16)),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Visit')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(v.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(children: [
            row(Icons.person_outline, 'Employee', e.name),
            row(Icons.place_outlined, 'Location', v.location),
            row(Icons.schedule, 'Scheduled', f.format(v.scheduledTime)),
            if (v.startedAt != null) row(Icons.play_arrow, 'Started', f.format(v.startedAt!)),
            if (v.completedAt != null) row(Icons.check_circle_outline, 'Completed', f.format(v.completedAt!)),
            if (v.outcome != null) row(v.outcome!.icon, 'Result', '${v.outcome!.label}${v.copies == null ? '' : ' · ${v.copies} copies'}'),
            if (v.outcomeNote != null) row(Icons.notes, 'Note', v.outcomeNote!),
            if (v.startedAt != null)
              ListTile(
                leading: const Icon(Icons.route, color: AppColors.muted),
                title: const Text('Distance travelled', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                subtitle: RouteKmText(load: load, from: v.startedAt!, to: v.completedAt ?? DateTime.now()),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        if (v.startedAt != null)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(slideRoute(RouteMapScreen(
              title: v.title,
              from: v.startedAt!,
              to: v.completedAt ?? DateTime.now(),
              load: load,
              live: v.status == VisitStatus.inProgress,
              destination: v.lat == null ? null : LatLng(v.lat!, v.lng!),
              personName: e.name,
              personInitials: e.initials,
              personPhoto: context.read<AccessProvider>().avatarOf(e.id),
            ))),
            icon: const Icon(Icons.map_outlined),
            label: const Text('See the route taken'),
          ),
        if (v.hasPhoto) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showPhoto(context, 'Photo', () => Api.adminVisitPhoto(v.id)),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('See photo of the place'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ]),
    );
  }
}
