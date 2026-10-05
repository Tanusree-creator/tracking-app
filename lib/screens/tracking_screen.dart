import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../services/demo_data.dart';
import '../services/location_service.dart';
import '../services/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/dark_tracking_map.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = context.watch<TrackingProvider>();
    final route = [for (final p in tr.points) LatLng(p.lat, p.lng)];
    final center = route.isEmpty ? DemoData.center : route.last;

    return Scaffold(
      appBar: AppBar(title: const Text('Live Location', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr.sharing ? 'Stop Sharing Location' : 'Start Sharing Location',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(tr.sharing ? 'Your admin can see where you are' : 'Share your position while on shift',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ]),
              ),
              Switch(value: tr.sharing, onChanged: (v) => v ? tr.startSharing() : tr.stopSharing()),
            ]),
          ),
        ),
        if (tr.locationError != null) ...[
          const SizedBox(height: 12),
          _Banner(
            icon: Icons.location_off,
            color: AppColors.red,
            text: tr.locationError!,
            action: tr.locationIssue == LocationIssue.deniedForever ? ('Settings', LocationService.openSettings) : null,
          ),
        ],
        if (tr.signalLost) ...[
          const SizedBox(height: 12),
          const _Banner(icon: Icons.signal_cellular_connected_no_internet_0_bar, color: AppColors.amber, text: 'Lost location signal.'),
        ],
        const SizedBox(height: 12),
        DarkTrackingMap(
          center: center,
          height: 320,
          route: route,
          markers: route.isEmpty ? const [] : [MapMarker(route.last, 'You')],
        ),
        const SizedBox(height: 12),
        if (route.isEmpty)
          const EmptyState(Icons.location_searching, 'No location data yet today')
        else
          Row(children: [
            Expanded(child: StatTile(icon: Icons.route, value: '${tr.distanceTodayKm.toStringAsFixed(2)} km', label: 'Distance Travelled')),
            const SizedBox(width: 12),
            Expanded(child: StatTile(icon: Icons.pin_drop, value: '${route.length}', label: 'Points Recorded', color: AppColors.green)),
          ]),
        if (tr.sharing) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: tr.togglePause,
            icon: Icon(tr.paused ? Icons.play_arrow : Icons.pause),
            label: Text(tr.paused ? 'Resume' : 'Pause'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          if (action != null) TextButton(onPressed: action!.$2, child: Text(action!.$1)),
        ]),
      );
}
