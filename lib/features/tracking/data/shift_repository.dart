import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Table / column names live here only, so a schema mismatch is a one-file fix.
class ShiftRepository {
  ShiftRepository(this._db);
  final SupabaseClient _db;

  Future<String?> activeShiftId(String employeeId) async {
    final row = await _db
        .from('shifts')
        .select('id')
        .eq('employee_id', employeeId)
        .isFilter('clock_out', null)
        .order('clock_in', ascending: false)
        .limit(1)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<String> clockIn(String employeeId) async {
    final row = await _db
        .from('shifts')
        .insert({
          'employee_id': employeeId,
          'clock_in': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> clockOut(String shiftId, double distanceMeters) => _db
      .from('shifts')
      .update({
        'clock_out': DateTime.now().toUtc().toIso8601String(),
        'route_distance_m': distanceMeters.round(),
      })
      .eq('id', shiftId);

  Future<void> insertPoints(
    String shiftId,
    String employeeId,
    List<Position> points,
  ) async {
    if (points.isEmpty) return;
    await _db.from('tracking_points').insert([
      for (final p in points)
        {
          'shift_id': shiftId,
          'employee_id': employeeId,
          'lat': p.latitude,
          'lon': p.longitude,
          'accuracy': p.accuracy,
          'recorded_at': p.timestamp.toUtc().toIso8601String(),
        },
    ]);
  }

  /// Saved route for a shift (used to redraw the trail after a restart / for admins).
  Future<List<({double lat, double lon})>> route(String shiftId) async {
    final rows = await _db
        .from('tracking_points')
        .select('lat,lon')
        .eq('shift_id', shiftId)
        .order('recorded_at');
    return [
      for (final r in rows)
        (lat: (r['lat'] as num).toDouble(), lon: (r['lon'] as num).toDouble()),
    ];
  }
}
