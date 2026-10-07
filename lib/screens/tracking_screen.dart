import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/demo_data.dart';
import '../services/location_service.dart';
import '../services/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/dark_tracking_map.dart';
import '../widgets/map_pins.dart';
import '../widgets/glass.dart';
import '../l10n/l10n.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  @override
  void initState() {
    super.initState();
    // Silent: shows the device position if permission is already granted.
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<TrackingProvider>().locateOnce());
  }

  (String, Color, IconData) _state(TrackingProvider tr) {
    if (tr.locationIssue == LocationIssue.servicesDisabled) return ('GPS off', AppColors.red, Icons.location_disabled);
    if (tr.locationIssue != null) return ('Permission missing', AppColors.red, Icons.block);
    if (tr.sharing && tr.signalLost) return ('Lost signal', AppColors.amber, Icons.signal_cellular_connected_no_internet_0_bar);
    if (tr.sharing && tr.paused) return ('Paused', AppColors.amber, Icons.pause_circle);
    if (tr.sharing) return ('Tracking active', AppColors.green, Icons.my_location);
    return ('Not sharing', AppColors.muted, Icons.location_searching);
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.watch<TrackingProvider>();
    final route = [for (final p in tr.points) LatLng(p.lat, p.lng)];
    final here = tr.current ?? (route.isEmpty ? null : route.last);
    final (stateLabel, stateColor, stateIcon) = _state(tr);

    return Scaffold(
      appBar: AppBar(title: Text('Live Location'.tr, style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: Sp.screen, children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(Sp.l),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.my_location, color: AppColors.accent),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Live tracking'.tr, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      (tr.clockedIn
                          ? (tr.onBreak ? 'Paused while you are on break' : 'Your admin can see where you are')
                          : 'Starts automatically when you clock in').tr,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: Sp.m),
              Align(alignment: Alignment.centerLeft, child: StatusChip(stateLabel, stateColor, icon: stateIcon)),
            ]),
          ),
        ),
        if (tr.locationError != null) ...[
          const SizedBox(height: Sp.m),
          _Banner(
            icon: Icons.location_off,
            color: AppColors.red,
            text: tr.locationError!,
            action: tr.locationIssue == LocationIssue.deniedForever
                ? ('Settings', LocationService.openSettings)
                : ('Enable', () => tr.locateOnce(prompt: true)),
          ),
        ],
        if (tr.signalLost) ...[
          const SizedBox(height: Sp.m),
          _Banner(icon: Icons.signal_cellular_connected_no_internet_0_bar, color: AppColors.amber, text: 'No location for 3 minutes. Check GPS, then battery settings below.'.tr),
        ],
        const SizedBox(height: Sp.m),
        DarkTrackingMap(
          center: here ?? DemoData.center,
          height: 320,
          zoom: here == null ? 11 : 15,
          route: route,
          markers: here == null ? const [] : [MapMarker(here, 'You')],
          extraMarkers: visitMarkers(context, tr.visits.where((v) => v.status != VisitStatus.completed || v.completedAt != null && DateUtils.isSameDay(v.completedAt, DateTime.now())).toList()),
        ),
        const SizedBox(height: Sp.s),
        const PinLegend(),
        const SizedBox(height: Sp.m),
        if (here == null && tr.locationError == null)
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(Sp.l),
              child: Column(children: [
                const Icon(Icons.location_searching, size: 40, color: AppColors.muted),
                const SizedBox(height: Sp.s),
                Text('No location data yet today'.tr, style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: Sp.m),
                OutlinedButton.icon(
                  onPressed: () => tr.locateOnce(prompt: true),
                  icon: const Icon(Icons.my_location),
                  label: Text('Enable location'.tr),
                ),
              ]),
            ),
          )
        else if (route.isNotEmpty)
          Row(children: [
            Expanded(child: StatTile(icon: Icons.route, value: '${tr.distanceTodayKm.toStringAsFixed(2)} km', label: 'Distance Travelled'.tr)),
            const SizedBox(width: Sp.m),
            Expanded(child: StatTile(icon: Icons.pin_drop, value: '${route.length}', label: 'Points Recorded'.tr, color: AppColors.green)),
          ]),
        const SizedBox(height: Sp.l),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(Sp.l),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.battery_saver, color: AppColors.amber),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Keep tracking running'.tr, style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: Sp.xs),
                  Text('Some phones stop apps in the background. Allow location "all the time" and set battery usage for Merit Publication to "Unrestricted".'.tr,
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  TextButton(onPressed: LocationService.openSettings, child: Text('Open app settings'.tr)),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final (String, Future<void> Function())? action;
  const _Banner({required this.icon, required this.color, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Sp.m),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text.tr)),
          if (action != null) TextButton(onPressed: action!.$2, child: Text(action!.$1.tr)),
        ]),
      );
}
