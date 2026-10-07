import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/dark_tracking_map.dart';
import '../l10n/l10n.dart';

class PickedPlace {
  final String name;
  final double lat;
  final double lng;
  const PickedPlace(this.name, this.lat, this.lng);
}

const _ua = {'User-Agent': 'MeritPublication/1.0 (field team app)', 'Accept-Language': 'en'};

/// Search an address (OpenStreetMap Nominatim) or tap the map to drop a pin.
class LocationPickerScreen extends StatefulWidget {
  final LatLng? start;
  const LocationPickerScreen({super.key, this.start});

  static Future<PickedPlace?> pick(BuildContext context, {LatLng? start}) =>
      Navigator.of(context).push<PickedPlace>(slideRoute(LocationPickerScreen(start: start)));

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _map = MapController();
  final _q = TextEditingController();
  Timer? _debounce;
  List<PickedPlace> _results = [];
  PickedPlace? _picked;
  bool _searching = false;
  bool _resolving = false;
  String? _msg;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(v.trim()));
  }

  Future<void> _search(String q) async {
    setState(() {
      _searching = true;
      _msg = null;
    });
    try {
      final res = await http
          .get(Uri.https('nominatim.openstreetmap.org', '/search', {'q': q, 'format': 'jsonv2', 'limit': '6'}), headers: _ua)
          .timeout(const Duration(seconds: 10));
      final list = jsonDecode(res.body) as List;
      if (!mounted) return;
      setState(() {
        _results = [
          for (final r in list)
            PickedPlace(r['display_name'] as String, double.parse(r['lat'] as String), double.parse(r['lon'] as String)),
        ];
        if (_results.isEmpty) _msg = 'No places found. Try a different search or tap the map.';
      });
    } catch (_) {
      if (mounted) setState(() => _msg = 'Search failed. Check your connection, or tap the map to place a pin.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _choose(PickedPlace p) {
    FocusScope.of(context).unfocus();
    setState(() {
      _picked = p;
      _results = [];
    });
    _map.move(LatLng(p.lat, p.lng), 16);
  }

  Future<void> _tap(LatLng ll) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _picked = PickedPlace('${ll.latitude.toStringAsFixed(5)}, ${ll.longitude.toStringAsFixed(5)}', ll.latitude, ll.longitude);
      _results = [];
      _resolving = true;
    });
    try {
      final res = await http
          .get(Uri.https('nominatim.openstreetmap.org', '/reverse', {'lat': '${ll.latitude}', 'lon': '${ll.longitude}', 'format': 'jsonv2'}), headers: _ua)
          .timeout(const Duration(seconds: 8));
      final name = (jsonDecode(res.body) as Map)['display_name'] as String?;
      if (mounted && name != null && _picked?.lat == ll.latitude) setState(() => _picked = PickedPlace(name, ll.latitude, ll.longitude));
    } catch (_) {
      // keep the coordinates as the name
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.start ?? DemoData.center;
    return Scaffold(
      appBar: AppBar(title: Text('Choose location'.tr)),
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(initialCenter: center, initialZoom: widget.start == null ? 11 : 15, onTap: (_, ll) => _tap(ll)),
          children: [
            themedTiles(context),
            if (_picked != null)
              MarkerLayer(markers: [
                Marker(
                    point: LatLng(_picked!.lat, _picked!.lng),
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on, color: AppColors.red, size: 44)),
              ]),
            const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
          ],
        ),
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: Column(children: [
            Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(16),
              color: AppColors.card(Theme.of(context).brightness == Brightness.dark),
              child: TextField(
                controller: _q,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => _search(v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search address or place'.tr,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      : (_q.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _q.clear(); _results = []; }))),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            if (_results.isNotEmpty || _msg != null)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: AppColors.card(Theme.of(context).brightness == Brightness.dark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.edge(Theme.of(context).brightness == Brightness.dark)),
                ),
                child: _results.isEmpty
                    ? Padding(padding: const EdgeInsets.all(16), child: Text(_msg!.tr, style: const TextStyle(color: AppColors.muted)))
                    : ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
                        for (final r in _results)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined, color: AppColors.accent),
                            title: Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                            onTap: () => _choose(r),
                          ),
                      ]),
              ),
          ]),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_picked != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  const Icon(Icons.location_on, color: AppColors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_picked!.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  if (_resolving) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
              )
            else
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Search above, or tap the map to drop a pin.'.tr, style: TextStyle(color: AppColors.muted)),
              ),
            FilledButton(onPressed: _picked == null ? null : () => Navigator.pop(context, _picked), child: Text('Use this location'.tr)),
          ]),
        ),
      ),
    );
  }
}

/// Read-only looking field that opens the picker. Use inside a Form.
class LocationField extends FormField<PickedPlace> {
  LocationField({super.key, required ValueChanged<PickedPlace> onPicked, PickedPlace? initial, LatLng? start})
      : super(
          initialValue: initial,
          validator: (v) => v == null ? 'Choose the visit location' : null,
          builder: (state) => InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final p = await LocationPickerScreen.pick(state.context, start: start);
              if (p != null) {
                state.didChange(p);
                onPicked(p);
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Visit location'.tr,
                prefixIcon: const Icon(Icons.place_outlined),
                suffixIcon: const Icon(Icons.map_outlined),
                errorText: state.errorText,
              ),
              child: Text(state.value?.name ?? 'Search or pick on map'.tr,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: state.value == null ? AppColors.muted : null)),
            ),
          ),
        );
}
