import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/access_provider.dart';
import '../../services/api.dart';
import '../../services/demo_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/dark_tracking_map.dart';
import '../../widgets/glass.dart';
import '../../widgets/map_pins.dart';
import 'admin_employee_detail_screen.dart';
import '../../l10n/l10n.dart';

/// Everyone's last known position (live feed) plus the task locations, on one map.
class AdminLiveMapScreen extends StatefulWidget {
  const AdminLiveMapScreen({super.key});

  @override
  State<AdminLiveMapScreen> createState() => _AdminLiveMapScreenState();
}

class _AdminLiveMapScreenState extends State<AdminLiveMapScreen> {
  final _map = MapController();
  List<Visit> _tasks = [];
  Map<String, String> _owner = {}; // visit id -> employee name
  Timer? _timer;
  bool _tasksOn = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loadTasks());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final rows = await Api.adminTaskPins();
      if (!mounted) return;
      setState(() {
        _tasks = [for (final r in rows) Visit.fromRemote(r)];
        _owner = {for (final r in rows) r['id'] as String: (r['user_name'] ?? '') as String};
      });
    } catch (_) {} // 005_profile_photo_map.sql not run yet: employees only
  }

  Color _color(Employee e) => e.status == DutyStatus.offDuty
      ? AppColors.muted
      : (e.status == DutyStatus.onBreak || !e.isLive ? AppColors.amber : AppColors.green);

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final emps = access.approved.where((e) => e.lat != null).toList();
    final centre = emps.isEmpty
        ? DemoData.center
        : LatLng(emps.fold(0.0, (a, e) => a + e.lat!) / emps.length, emps.fold(0.0, (a, e) => a + e.lng!) / emps.length);

    final markers = <Marker>[
      if (_tasksOn)
        for (final v in _tasks.where((v) => v.lat != null))
          Marker(
            point: LatLng(v.lat!, v.lng!),
            width: 44,
            height: 44,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => showVisitPinSheet(context, v, who: _owner[v.id]),
              child: MapPin(color: visitPinStyle(v.status).$1, icon: visitPinStyle(v.status).$2),
            ),
          ),
      for (final e in emps)
        Marker(
          point: LatLng(e.lat!, e.lng!),
          width: 54,
          height: 54,
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(slideRoute(AdminEmployeeDetailScreen(e))),
            child: Tooltip(message: e.name, child: PersonPin(initials: e.initials, photo: access.avatarOf(e.id), color: _color(e), size: 50)),
          ),
        ),
    ];

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: centre, initialZoom: 12),
            children: [
              themedTiles(context),
              MarkerLayer(markers: markers),
              const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.m, Sp.s, Sp.m, 0),
              child: GlassCard(
                radius: 26,
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
                  Expanded(child: Text('Live field map'.tr, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  IconButton(
                    tooltip: _tasksOn ? 'Hide task locations' : 'Show task locations',
                    icon: Icon(_tasksOn ? Icons.flag_rounded : Icons.flag_outlined, color: _tasksOn ? AppColors.red : null),
                    onPressed: () => setState(() => _tasksOn = !_tasksOn),
                  ),
                  IconButton(
                    tooltip: 'Refresh'.tr,
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      access.refresh(silent: true);
                      _loadTasks();
                    },
                  ),
                ]),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Sp.m),
              child: GlassCard(
                radius: 24,
                padding: const EdgeInsets.all(Sp.m),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(emps.isEmpty ? 'No employee positions yet'.tr : trf('{} on the map', [trCount(emps.length, 'employee', 'employees')]), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: Sp.s),
                  const Wrap(spacing: Sp.s, runSpacing: 4, children: [
                    StatusChip('Live', AppColors.green),
                    StatusChip('Idle / break', AppColors.amber),
                    StatusChip('Offline', AppColors.muted),
                    StatusChip('Task to do', AppColors.red, icon: Icons.flag_rounded),
                    StatusChip('Done', AppColors.green, icon: Icons.check_rounded),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
