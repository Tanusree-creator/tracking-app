import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/location_service.dart';
import '../../../core/providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/shift_repository.dart';

final shiftRepositoryProvider =
    Provider((ref) => ShiftRepository(ref.watch(supabaseProvider)));

class TrackingState {
  const TrackingState({
    this.shiftId,
    this.trail = const [],
    this.distanceM = 0,
    this.busy = false,
    this.error,
  });

  final String? shiftId;
  final List<LatLng> trail;
  final double distanceM;
  final bool busy;
  final String? error;

  bool get onShift => shiftId != null;
  LatLng? get last => trail.isEmpty ? null : trail.last;

  TrackingState copyWith({
    String? shiftId,
    bool clearShift = false,
    List<LatLng>? trail,
    double? distanceM,
    bool? busy,
    String? error,
    bool clearError = false,
  }) =>
      TrackingState(
        shiftId: clearShift ? null : (shiftId ?? this.shiftId),
        trail: trail ?? this.trail,
        distanceM: distanceM ?? this.distanceM,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );
}

class TrackingController extends Notifier<TrackingState> {
  StreamSubscription<Position>? _sub;
  Timer? _flushTimer;
  final List<Position> _pending = [];
  Position? _prev;

  ShiftRepository get _repo => ref.read(shiftRepositoryProvider);
  String get _uid => ref.read(authProvider)!.id;

  @override
  TrackingState build() {
    ref.onDispose(_stopStream);
    return const TrackingState();
  }

  /// Call after login: resumes an open shift (e.g. after the app was killed).
  Future<void> restore() async {
    try {
      final id = await _repo.activeShiftId(_uid);
      if (id == null) return;
      final saved = await _repo.route(id);
      final trail = [for (final p in saved) LatLng(p.lat, p.lon)];
      var dist = 0.0;
      for (var i = 1; i < trail.length; i++) {
        dist += const Distance().as(LengthUnit.Meter, trail[i - 1], trail[i]);
      }
      state = state.copyWith(shiftId: id, trail: trail, distanceM: dist);
      await _startStream();
    } catch (e) {
      state = state.copyWith(error: 'Could not restore shift: $e');
    }
  }

  Future<void> clockIn() async {
    state = state.copyWith(busy: true, clearError: true);
    final loc = ref.read(locationServiceProvider);
    final access = await loc.ensurePermission();
    if (access != LocationAccess.granted) {
      state = state.copyWith(busy: false, error: _accessMessage(access));
      return;
    }
    try {
      final id = await _repo.clockIn(_uid);
      await ref.read(appPrefsProvider).setActiveShiftId(id);
      state = TrackingState(shiftId: id);
      await _startStream();
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Clock-in failed: $e');
    }
  }

  Future<void> clockOut() async {
    final id = state.shiftId;
    if (id == null) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _flush();
      await _repo.clockOut(id, state.distanceM);
      await _stopStream();
      await ref.read(appPrefsProvider).setActiveShiftId(null);
      state = const TrackingState();
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Clock-out failed: $e');
    }
  }

  Future<void> _startStream() async {
    await _stopStream();
    _prev = null;
    _sub = ref.read(locationServiceProvider).trackingStream().listen(
      _onPosition,
      onError: (Object e) =>
          state = state.copyWith(error: 'Location error: $e'),
    );
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => _flush());
    state = state.copyWith(busy: false);
  }

  void _onPosition(Position p) {
    final prev = _prev;
    final step = prev == null
        ? 0.0
        : Geolocator.distanceBetween(
            prev.latitude, prev.longitude, p.latitude, p.longitude);
    _prev = p;
    _pending.add(p);
    state = state.copyWith(
      trail: [...state.trail, LatLng(p.latitude, p.longitude)],
      distanceM: state.distanceM + step,
    );
    if (_pending.length >= 20) _flush();
  }

  /// Uploads buffered points; on failure they stay queued for the next attempt.
  Future<void> _flush() async {
    final id = state.shiftId;
    if (id == null || _pending.isEmpty) return;
    final batch = List<Position>.of(_pending);
    _pending.clear();
    try {
      await _repo.insertPoints(id, _uid, batch);
    } catch (e) {
      debugPrint('Tracking upload failed, will retry: $e');
      _pending.insertAll(0, batch);
    }
  }

  Future<void> _stopStream() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _sub?.cancel();
    _sub = null;
  }

  String _accessMessage(LocationAccess a) => switch (a) {
        LocationAccess.serviceOff => 'Turn on location services to clock in.',
        LocationAccess.deniedForever =>
          'Location is blocked. Enable it in Settings to clock in.',
        _ => 'Location permission is required to clock in.',
      };
}

final trackingProvider =
    NotifierProvider<TrackingController, TrackingState>(TrackingController.new);
