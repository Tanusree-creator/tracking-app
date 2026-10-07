import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import 'map_pins.dart';

class MapMarker {
  final LatLng position;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const MapMarker(this.position, this.label, {this.color = AppColors.accent, this.onTap});
}

// Inverts the light OSM tiles into a dark map (no API key needed).
const _invert = ColorFilter.matrix(<double>[
  -0.9, 0, 0, 0, 240, //
  0, -0.9, 0, 0, 240,
  0, 0, -0.9, 0, 240,
  0, 0, 0, 1, 0,
]);

/// OSM tiles, inverted into a dark map when the app is in dark mode.
Widget themedTiles(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final tiles = TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.example.trackingapp',
  );
  return dark ? ColorFiltered(colorFilter: _invert, child: tiles) : tiles;
}

class DarkTrackingMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final List<LatLng> route;
  final List<MapMarker> markers;
  final double height;
  final List<Marker> extraMarkers; // e.g. task pins from visitMarkers()

  const DarkTrackingMap({
    super.key,
    required this.center,
    this.zoom = 14,
    this.route = const [],
    this.markers = const [],
    this.height = 260,
    this.extraMarkers = const [],
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tiles = TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.trackingapp',
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          key: ValueKey(center),
          options: MapOptions(initialCenter: center, initialZoom: zoom),
          children: [
            dark ? ColorFiltered(colorFilter: _invert, child: tiles) : tiles,
            if (route.length > 1)
              PolylineLayer(polylines: [Polyline(points: route, strokeWidth: 5, color: AppColors.accent, borderStrokeWidth: 2, borderColor: Colors.white)]),
            MarkerLayer(markers: [
              ...extraMarkers,
              for (final m in markers)
                Marker(
                  point: m.position,
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: m.onTap,
                    child: Tooltip(message: m.label, child: MapPin(color: m.color, icon: Icons.person)),
                  ),
                ),
            ]),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
            ),
          ],
        ),
      ),
    );
  }
}
