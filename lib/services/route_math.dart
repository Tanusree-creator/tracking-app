import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';

const kMaxAccuracyM = 25.0;
const kMinStepM = 5.0;
const kMaxJumpMps = 55.0; // ~200 km/h: anything faster is a GPS jump

/// Decides whether a raw GPS fix is good enough to keep.
/// [last] is the previously accepted fix (or null).
bool acceptFix(Position p, Position? last) {
  if (p.isMocked) return false;
  if (p.accuracy > kMaxAccuracyM) return false;
  if (DateTime.now().difference(p.timestamp).inSeconds > 30) return false; // stale
  if (last != null) {
    final dt = p.timestamp.difference(last.timestamp).inSeconds;
    final d = Geolocator.distanceBetween(last.latitude, last.longitude, p.latitude, p.longitude);
    if (dt > 0 && d / dt > kMaxJumpMps) return false;
    if (d < math.max(kMinStepM, p.accuracy * .5) && p.speed < .5) return false; // standing still jitter
  }
  return true;
}

const _dist = Distance();

/// Route length in km. Same filtered points drive both the drawn line and this total.
double routeKm(List<LocationPoint> pts) {
  var m = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final d = _dist(LatLng(pts[i - 1].lat, pts[i - 1].lng), LatLng(pts[i].lat, pts[i].lng));
    if (d < kMinStepM) continue; // jitter
    final dt = pts[i].timestamp.difference(pts[i - 1].timestamp).inSeconds;
    if (dt > 0 && d / dt > kMaxJumpMps) continue; // impossible jump
    m += d;
  }
  return m / 1000;
}

/// Splits a route into segments wherever there is a gap (tracking lost) so the map
/// doesn't draw a straight line across it. Returns (segments, gapLines).
({List<List<LatLng>> solid, List<List<LatLng>> gaps}) splitRoute(List<LocationPoint> pts,
    {Duration gap = const Duration(minutes: 3)}) {
  final solid = <List<LatLng>>[];
  final gaps = <List<LatLng>>[];
  var cur = <LatLng>[];
  for (var i = 0; i < pts.length; i++) {
    final ll = LatLng(pts[i].lat, pts[i].lng);
    if (i > 0 && pts[i].timestamp.difference(pts[i - 1].timestamp) > gap) {
      if (cur.length > 1) solid.add(cur);
      gaps.add([LatLng(pts[i - 1].lat, pts[i - 1].lng), ll]);
      cur = [];
    }
    cur.add(ll);
  }
  if (cur.length > 1) solid.add(cur);
  return (solid: solid, gaps: gaps);
}
