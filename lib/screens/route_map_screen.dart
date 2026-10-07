import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../services/demo_data.dart';
import '../services/route_math.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';
import '../widgets/dark_tracking_map.dart';
import '../widgets/glass.dart';
import '../widgets/map_pins.dart';
import '../l10n/l10n.dart';

typedef RouteLoader = Future<List<Map<String, dynamic>>> Function(DateTime from, DateTime to);

/// The path taken in a time window, with distance. [live] re-polls every 8 s and follows the last point.
/// Employees pass [Api.myRoute]; admins pass a loader bound to an employee.
class RouteMapScreen extends StatefulWidget {
  final String title;
  final DateTime from;
  final DateTime to;
  final bool live;
  final RouteLoader load;
  final LatLng? destination; // e.g. the visit location
  final String? destinationLabel;
  final List<Visit> visits; // task locations shown as pins
  final String? personName; // whose route this is (admin view)
  final String personInitials;
  final Uint8List? personPhoto;

  const RouteMapScreen({
    super.key,
    required this.title,
    required this.from,
    required this.to,
    required this.load,
    this.live = false,
    this.destination,
    this.destinationLabel,
    this.visits = const [],
    this.personName,
    this.personInitials = '',
    this.personPhoto,
  });

  /// Today's route for the signed-in employee, refreshing live.
  factory RouteMapScreen.today({Key? key, List<Visit> visits = const []}) {
    final n = DateTime.now();
    return RouteMapScreen(
        key: key,
        title: "Today's route".tr,
        from: DateTime(n.year, n.month, n.day),
        to: DateTime(n.year, n.month, n.day, 23, 59, 59),
        live: true,
        load: Api.myRoute,
        visits: visits);
  }

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final _map = MapController();
  List<LocationPoint> _pts = [];
  Timer? _timer;
  bool _loading = true;
  String? _error;
  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.live) _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final to = widget.live ? DateTime.now().add(const Duration(minutes: 1)) : widget.to;
      final rows = await widget.load(widget.from, to);
      if (!mounted) return;
      setState(() {
        _pts = rows.map(LocationPoint.fromRemote).toList();
        _loading = false;
        _error = null;
      });
      if (_pts.isNotEmpty) {
        if (!_fitted && _pts.length > 1) {
          _fitted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              _map.fitCamera(CameraFit.coordinates(
                  coordinates: [for (final p in _pts) LatLng(p.lat, p.lng)], padding: const EdgeInsets.all(56), maxZoom: 17));
            } catch (_) {}
          });
        } else if (widget.live) {
          try {
            _map.move(LatLng(_pts.last.lat, _pts.last.lng), _map.camera.zoom);
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final km = routeKm(_pts);
    final last = _pts.isEmpty ? null : _pts.last;
    final isLive = widget.live && last != null && DateTime.now().difference(last.timestamp) < const Duration(minutes: 2);
    final split = splitRoute(_pts);
    final dateFmt = DateFormat('EEE, d MMM y');
    final timeFmt = DateFormat('h:mm a');

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = ErrorState(_error!, _load);
    } else if (_pts.isEmpty) {
      body = const EmptyState(Icons.route_outlined, 'No location points were recorded for this period.');
    } else {
      final start = LatLng(_pts.first.lat, _pts.first.lng);
      final end = LatLng(last!.lat, last.lng);
      body = Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(initialCenter: end, initialZoom: 15),
          children: [
            themedTiles(context),
            PolylineLayer(polylines: [
              for (final seg in split.solid) Polyline(points: seg, strokeWidth: 6, color: AppColors.accent, borderStrokeWidth: 2.5, borderColor: Colors.white, strokeJoin: StrokeJoin.round),
              for (final g in split.gaps)
                Polyline(points: g, strokeWidth: 3, color: AppColors.amber, pattern: StrokePattern.dashed(segments: const [8, 8])),
            ]),
            if (last.accuracy != null)
              CircleLayer(circles: [
                CircleMarker(point: end, radius: last.accuracy!, useRadiusInMeter: true, color: AppColors.accent.withValues(alpha: .15), borderColor: AppColors.accent.withValues(alpha: .4), borderStrokeWidth: 1),
              ]),
            MarkerLayer(markers: [
              ...visitMarkers(context, widget.visits, who: widget.personName),
              if (widget.destination != null)
                Marker(point: widget.destination!, width: 44, height: 44, alignment: Alignment.topCenter, child: const MapPin(color: kDestinationColor, icon: Icons.place_rounded)),
              Marker(point: start, width: 40, height: 40, child: const _RoundPin(AppColors.green, Icons.play_arrow_rounded)),
              Marker(
                point: end,
                width: 54,
                height: 54,
                child: widget.personName != null
                    ? PersonPin(initials: widget.personInitials, photo: widget.personPhoto, color: isLive ? AppColors.green : AppColors.muted, size: 50)
                    : const _RoundPin(AppColors.accent, Icons.navigation_rounded),
              ),
            ]),
            const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
          ],
        ),
      ]);
    }

    final stats = GlassCard(
      radius: 26,
      padding: const EdgeInsets.all(Sp.l),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (widget.personName != null) ...[
            UserAvatar(photo: widget.personPhoto, initials: widget.personInitials, radius: 22),
            const SizedBox(width: Sp.m),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.personName != null) Text(widget.personName!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text('${km.toStringAsFixed(2)} km', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                dateFmt.format(widget.from) + (_pts.isEmpty ? '' : '  ·  ${timeFmt.format(_pts.first.timestamp)} – ${timeFmt.format(_pts.last.timestamp)}'),
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ]),
          ),
          if (widget.live)
            isLive
                ? const StatusChip('Live', AppColors.green)
                : StatusChip(last == null ? 'No signal' : trf('Last seen {}', [timeFmt.format(last.timestamp)]), AppColors.muted),
        ]),
        const SizedBox(height: Sp.m),
        Wrap(spacing: Sp.s, runSpacing: 4, children: [
          const StatusChip('Start', AppColors.green, icon: Icons.play_arrow_rounded),
          StatusChip(widget.personName != null ? 'Employee now' : 'You', AppColors.accent, icon: Icons.navigation_rounded),
          if (widget.destination != null) const StatusChip('Destination', kDestinationColor, icon: Icons.place_rounded),
          if (widget.visits.any((v) => v.lat != null)) const StatusChip('Task to do', AppColors.red, icon: Icons.flag_rounded),
          if (split.gaps.isNotEmpty) const StatusChip('Dashed = signal lost', AppColors.amber),
        ]),
      ]),
    );

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: body),
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
                  Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  IconButton(
                    tooltip: 'Fit route'.tr,
                    icon: const Icon(Icons.center_focus_strong_outlined),
                    onPressed: _pts.length < 2 ? null : () => _map.fitCamera(CameraFit.coordinates(coordinates: [for (final p in _pts) LatLng(p.lat, p.lng)], padding: const EdgeInsets.all(72), maxZoom: 17)),
                  ),
                ]),
              ),
            ),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(child: Padding(padding: const EdgeInsets.all(Sp.m), child: stats))),
      ]),
    );
  }
}

/// Round pointer with a white ring, readable on light and dark maps.
class _RoundPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _RoundPin(this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .6), blurRadius: 12, spreadRadius: 1), const BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(0, 2))],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      );
}

/// Distance for a window (used in lists). Loads on demand and caches by key.
class RouteKmText extends StatefulWidget {
  final RouteLoader load;
  final DateTime from, to;
  const RouteKmText({super.key, required this.load, required this.from, required this.to});

  @override
  State<RouteKmText> createState() => _RouteKmTextState();
}

class _RouteKmTextState extends State<RouteKmText> {
  late final Future<double> _f = widget.load(widget.from, widget.to).then((r) => routeKm(r.map(LocationPoint.fromRemote).toList()));

  @override
  Widget build(BuildContext context) => FutureBuilder<double>(
        future: _f,
        builder: (_, s) => Text(s.hasData ? '${s.data!.toStringAsFixed(1)} km' : (s.hasError ? '– km' : '…'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}

const kDefaultCenter = DemoData.center;
