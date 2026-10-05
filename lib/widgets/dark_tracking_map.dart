import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';

class MapMarker {
  final LatLng position;
  final String label;
  final Color color;
  const MapMarker(this.position, this.label, {this.color = AppColors.accent});
}

class DarkTrackingMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final List<LatLng> route;
  final List<MapMarker> markers;
  final double height;

  const DarkTrackingMap({
    super.key,
    required this.center,
    this.zoom = 14,
    this.route = const [],
    this.markers = const [],
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: height,
          child: FlutterMap(
            key: ValueKey(center),
            options: MapOptions(initialCenter: center, initialZoom: zoom),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.trackingapp',
              ),
              if (route.length > 1)
                PolylineLayer(polylines: [Polyline(points: route, strokeWidth: 4, color: AppColors.accent)]),
              MarkerLayer(markers: [
                for (final m in markers)
                  Marker(
                    point: m.position,
                    width: 40,
                    height: 40,
                    child: Tooltip(
                      message: m.label,
                      child: Icon(Icons.location_on, color: m.color, size: 36),
                    ),
                  ),
              ]),
            ],
          ),
        ),
      );
}
