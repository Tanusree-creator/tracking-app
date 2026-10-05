import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/env.dart';

/// TomTom map with the GPS trail and a marker at the latest position.
class RouteMap extends StatefulWidget {
  const RouteMap({super.key, required this.trail});
  final List<LatLng> trail;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final _controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    final last = widget.trail.isEmpty ? null : widget.trail.last;
    if (_ready && last != null && widget.trail.length != old.trail.length) {
      _controller.move(last, _controller.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = widget.trail.isEmpty ? null : widget.trail.last;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: last ?? const LatLng(20.5937, 78.9629),
          initialZoom: last == null ? 4 : 16,
          onMapReady: () => _ready = true,
        ),
        children: [
          TileLayer(
            urlTemplate: Env.tomtomTiles,
            userAgentPackageName: 'com.example.trackingapp',
          ),
          if (widget.trail.length > 1)
            PolylineLayer(polylines: [
              Polyline(
                points: widget.trail,
                strokeWidth: 5,
                color: scheme.primary,
              ),
            ]),
          if (last != null)
            MarkerLayer(markers: [
              Marker(
                point: last,
                width: 44,
                height: 44,
                child: Icon(Icons.my_location, color: scheme.primary, size: 34),
              ),
            ]),
        ],
      ),
    );
  }
}
