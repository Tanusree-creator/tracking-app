import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'api.dart';
import 'app_notifications_provider.dart';
import 'location_service.dart';
import 'route_math.dart';

/// Employee-side state. Local-first (works offline) and synced to Supabase:
/// shifts, visits and GPS points are pushed, admin-assigned tasks and chat are pulled.
class TrackingProvider extends ChangeNotifier {
  final AppNotificationsProvider _alerts;
  TrackingProvider(this._alerts);

  String? _userId;
  List<Shift> shifts = [];
  List<Visit> visits = [];
  List<LocationPoint> points = []; // today's points, for the live distance
  final List<LocationPoint> _outbox = []; // accepted points not yet confirmed by the server

  bool sharing = false;
  bool paused = false;
  bool signalLost = false;
  bool offline = false;
  String? locationError;
  LocationIssue? locationIssue;
  int unreadChat = 0;
  int dailyTarget = 3; // set by the admin

  LatLng? current;
  double? currentAccuracy;
  DateTime? lastFixAt;
  Position? _lastAccepted;
  StreamSubscription<Position>? _sub;
  Timer? _watchdog;
  Timer? _ticker;
  Timer? _flushTimer;
  Timer? _pullTimer;
  bool _flushing = false;
  final _knownAdminVisits = <String>{};
  bool _firstPull = true;

  // ── lifecycle ──────────────────────────────────────────────────────────────
  Future<void> load(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tracking_$userId');
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      shifts = (j['shifts'] as List).map((e) => Shift.fromJson(e)).toList();
      visits = (j['visits'] as List).map((e) => Visit.fromJson(e)).toList();
      points = (j['points'] as List).map((e) => LocationPoint.fromJson(e)).where((p) => _isToday(p.timestamp)).toList();
      _outbox
        ..clear()
        ..addAll(((j['outbox'] ?? []) as List).map((e) => LocationPoint.fromJson(e)));
    }
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => notifyListeners());
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 15), (_) => _flush());
    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(const Duration(seconds: 20), (_) => pull());
    notifyListeners();
    await pull();
    _checkMissedVisits();
    // Shift was left open (app killed / phone restarted): resume tracking.
    if (clockedIn && !onBreak) startSharing();
  }

  void reset() {
    _stopStream();
    _ticker?.cancel();
    _flushTimer?.cancel();
    _pullTimer?.cancel();
    _userId = null;
    shifts = [];
    visits = [];
    points = [];
    _outbox.clear();
    _knownAdminVisits.clear();
    _firstPull = true;
    unreadChat = 0;
    sharing = paused = signalLost = false;
    locationError = null;
    notifyListeners();
  }

  Future<void> _save() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'tracking_$_userId',
      jsonEncode({
        'shifts': shifts.map((s) => s.toJson()).toList(),
        'visits': visits.map((v) => v.toJson()).toList(),
        'points': points.map((p) => p.toJson()).toList(),
        'outbox': _outbox.map((p) => p.toJson()).toList(),
      }),
    );
  }

  // ── server sync ────────────────────────────────────────────────────────────
  /// Pull admin-assigned tasks, server shifts and unread chat; push anything still unsynced.
  Future<void> pull() async {
    if (_userId == null) return;
    try {
      await _pushPending();
      final remoteVisits = (await Api.myVisits()).map(Visit.fromRemote).toList();
      final remoteShifts = (await Api.myShifts()).map(Shift.fromRemote).toList();
      final unread = await Api.myUnreadChat();
      offline = false;
      try {
        dailyTarget = await Api.dailyTarget();
      } catch (_) {} // 006 not run yet: keep the default

      // Local unsynced changes win; everything else follows the server.
      final localUnsynced = {for (final v in visits.where((v) => !v.synced)) v.id: v};
      final merged = <Visit>[];
      for (final r in remoteVisits) {
        final l = localUnsynced.remove(r.id);
        if (l != null) {
          merged.add(l);
        } else {
          final old = visits.where((v) => v.id == r.id).firstOrNull;
          r.hasPhoto = r.hasPhoto || (old?.hasPhoto ?? false);
          merged.add(r);
        }
        if (r.byAdmin && !_knownAdminVisits.contains(r.id)) {
          if (!_firstPull && r.status == VisitStatus.pending) {
            _alerts.add('New task assigned', '${r.title} · ${r.location}', AlertAudience.employee);
          }
          _knownAdminVisits.add(r.id);
        }
      }
      merged.addAll(localUnsynced.values);
      merged.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      visits = merged;

      final open = shifts.where((s) => s.isOpen).firstOrNull;
      final remoteIds = remoteShifts.map((s) => s.id).toSet();
      shifts = [
        ...remoteShifts,
        if (open != null && !remoteIds.contains(open.id)) open,
      ];

      if (!_firstPull && unread > unreadChat) {
        _alerts.add('New message from admin', 'Open Chat to read it.', AlertAudience.employee);
      }
      unreadChat = unread;
      _firstPull = false;
      await _save();
      notifyListeners();
    } catch (e) {
      if (e is NetworkException) {
        offline = true;
        notifyListeners();
      }
    }
  }

  Future<void> _pushPending() async {
    for (final s in shifts) {
      await _syncShift(s);
    }
    for (final v in visits.where((v) => !v.synced)) {
      await _syncVisit(v);
    }
  }

  Future<void> _syncShift(Shift s) async {
    try {
      await Api.syncShift({
        'id': s.id,
        'start': s.start.toUtc().toIso8601String(),
        'end': s.end?.toUtc().toIso8601String(),
        'breaks': s.breaks
            .map((b) => {'start': b.start.toUtc().toIso8601String(), 'end': b.end?.toUtc().toIso8601String()})
            .toList(),
      });
    } catch (_) {/* retried on the next pull */}
  }

  Future<void> _syncVisit(Visit v) async {
    try {
      await Api.syncVisit({
        'id': v.id,
        'title': v.title,
        'location': v.location,
        'lat': v.lat,
        'lng': v.lng,
        'scheduled': v.scheduledTime.toUtc().toIso8601String(),
        'status': v.status.name,
        'started': v.startedAt?.toUtc().toIso8601String(),
        'completed': v.completedAt?.toUtc().toIso8601String(),
        'photo': v.photoB64,
        'outcome': v.outcome?.name,
        'note': v.outcomeNote,
        'copies': v.copies,
      });
      v.synced = true;
      v.photoB64 = null; // server has it now
      await _save();
    } catch (_) {
      // stays unsynced and is retried
    }
  }

  Future<void> _flush() async {
    if (_flushing || _outbox.isEmpty) return;
    _flushing = true;
    try {
      final batch = _outbox.take(200).toList();
      await Api.addPoints(batch.map((p) => p.toUpload()).toList());
      _outbox.removeRange(0, batch.length);
      offline = false;
      await _save();
    } catch (e) {
      if (e is NetworkException) offline = true;
      // points stay in the outbox and are retried
    } finally {
      _flushing = false;
    }
  }

  void _checkMissedVisits() {
    final now = DateTime.now();
    final missed = visits.where((v) =>
        v.status == VisitStatus.pending && _isToday(v.scheduledTime) && now.difference(v.scheduledTime) > const Duration(minutes: 30));
    if (missed.isNotEmpty) {
      _alerts.add('Missed visit reminder', '${missed.first.title} was scheduled for ${_hm(missed.first.scheduledTime)}.',
          AlertAudience.employee);
    }
  }

  // ── shift ──────────────────────────────────────────────────────────────────
  Shift? get openShift => shifts.where((s) => s.isOpen).firstOrNull;
  bool get clockedIn => openShift != null;
  bool get onBreak => openShift?.onBreak ?? false;

  /// Call after face verification succeeds.
  Future<void> clockIn() async {
    if (clockedIn) return;
    final s = Shift(id: const Uuid().v4(), start: DateTime.now());
    shifts.add(s);
    _alerts.add('Shift started', 'You clocked in at ${_hm(s.start)}.', AlertAudience.employee, notify: false);
    notifyListeners();
    await _save();
    _syncShift(s);
    await startSharing();
  }

  Future<void> clockOut() async {
    final open = openShift;
    if (open == null) return;
    if (open.onBreak) open.breaks.last.end = DateTime.now();
    open.end = DateTime.now();
    stopSharing();
    _alerts.add('Shift ended', 'Worked ${fmtDuration(open.worked)} today.', AlertAudience.employee, notify: false);
    await _save();
    notifyListeners();
    await _flush();
    _syncShift(open);
  }

  Future<void> startBreak() async {
    final open = openShift;
    if (open == null || open.onBreak) return;
    open.breaks.add(ShiftBreak(DateTime.now()));
    paused = true;
    await _save();
    notifyListeners();
    _syncShift(open);
  }

  /// Call after face verification succeeds.
  Future<void> endBreak() async {
    final open = openShift;
    if (open == null || !open.onBreak) return;
    open.breaks.last.end = DateTime.now();
    paused = false;
    await _save();
    notifyListeners();
    _syncShift(open);
    if (!sharing) await startSharing();
  }

  // ── visits ─────────────────────────────────────────────────────────────────
  Future<void> addVisit(String title, String location, DateTime time, {double? lat, double? lng}) async {
    final v = Visit(id: const Uuid().v4(), title: title, location: location, scheduledTime: time, lat: lat, lng: lng);
    visits.add(v);
    visits.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    notifyListeners();
    await _save();
    _syncVisit(v);
  }

  Future<void> startVisit(Visit v) async {
    v.status = VisitStatus.inProgress;
    v.startedAt = DateTime.now();
    v.synced = false;
    notifyListeners();
    await _save();
    _syncVisit(v);
  }

  /// A visit only counts as completed once a photo of the place is attached.
  Future<void> completeVisit(Visit v, String photoB64, {required VisitOutcome outcome, String? note, int? copies}) async {
    v.outcome = outcome;
    v.outcomeNote = note;
    v.copies = outcome.hasCopies ? copies : null;
    v.status = VisitStatus.completed;
    v.completedAt = DateTime.now();
    v.photoB64 = photoB64;
    v.hasPhoto = true;
    v.synced = false;
    _alerts.add('Visit completed', '${v.title} at ${v.location}', AlertAudience.employee, notify: false);
    notifyListeners();
    await _save();
    _syncVisit(v);
  }

  List<Visit> get todaysVisits => visits.where((v) => _isToday(v.scheduledTime)).toList();

  // ── stats ──────────────────────────────────────────────────────────────────
  Duration get hoursToday => shifts.where((s) => _isToday(s.start)).fold(Duration.zero, (a, s) => a + s.worked);

  int get visitsCompleted => visits.where((v) => v.status == VisitStatus.completed).length;

  List<Visit> get finishedToday =>
      visits.where((v) => v.status == VisitStatus.completed && v.completedAt != null && _isToday(v.completedAt!)).toList();

  int get jobsFinishedToday => finishedToday.length;

  double get distanceTodayKm => routeKm(points);

  /// Consecutive days (ending today, or yesterday if nothing is closed yet today) with at least one closed visit.
  int get streakDays {
    final days = {
      for (final v in visits.where((v) => v.status == VisitStatus.completed && v.completedAt != null))
        DateTime(v.completedAt!.year, v.completedAt!.month, v.completedAt!.day)
    };
    var d = DateTime.now();
    d = DateTime(d.year, d.month, d.day);
    if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(d)) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  // ── history ────────────────────────────────────────────────────────────────
  List<Shift> get closedShifts => shifts.where((s) => !s.isOpen).toList()..sort((a, b) => b.start.compareTo(a.start));

  Map<DateTime, double> get hoursByDay {
    final map = <DateTime, double>{};
    for (final s in shifts) {
      final d = DateTime(s.start.year, s.start.month, s.start.day);
      map[d] = (map[d] ?? 0) + s.worked.inMinutes / 60;
    }
    return map;
  }

  // ── location sharing ───────────────────────────────────────────────────────
  /// Show the device position on the map. Silent unless [prompt] is true.
  Future<void> locateOnce({bool prompt = false}) async {
    try {
      if (prompt) {
        await LocationService.ensureReady();
        locationError = null;
        locationIssue = null;
      } else if (!await LocationService.isAllowed()) {
        return;
      }
      final p = await LocationService.currentPosition();
      current = LatLng(p.latitude, p.longitude);
      currentAccuracy = p.accuracy;
    } on LocationException catch (e) {
      locationError = e.message;
      locationIssue = e.issue;
    } catch (_) {
      // no GPS fix yet; the map falls back to the default view
    }
    notifyListeners();
  }

  Future<void> startSharing() async {
    if (_sub != null) return;
    locationError = null;
    locationIssue = null;
    try {
      await LocationService.ensureReady();
    } on LocationException catch (e) {
      locationError = e.message;
      locationIssue = e.issue;
      notifyListeners();
      return;
    }
    sharing = true;
    paused = onBreak;
    signalLost = false;
    _lastAccepted = null;
    _sub = LocationService.stream().listen(_onPosition, onError: (_) {
      signalLost = true;
      notifyListeners();
    });
    _armWatchdog();
    notifyListeners();
  }

  void stopSharing() {
    _stopStream();
    sharing = false;
    paused = false;
    signalLost = false;
    _save();
    notifyListeners();
  }

  void _onPosition(Position p) {
    signalLost = false;
    _armWatchdog();
    current = LatLng(p.latitude, p.longitude);
    currentAccuracy = p.accuracy;
    lastFixAt = DateTime.now();
    if (!paused && acceptFix(p, _lastAccepted)) {
      _lastAccepted = p;
      final pt = LocationPoint(p.latitude, p.longitude, p.timestamp.toLocal(),
          accuracy: p.accuracy, speed: p.speed, heading: p.heading);
      points.add(pt);
      _outbox.add(pt);
      if (_outbox.length % 3 == 0) _save();
      if (_outbox.length >= 6) _flush();
    }
    notifyListeners();
  }

  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(minutes: 3), () {
      if (sharing && !paused) {
        signalLost = true;
        _alerts.add('Tracking lost', 'No location received for 3 minutes. Open the app and check GPS and battery settings.',
            AlertAudience.employee);
        notifyListeners();
      }
    });
  }

  void _stopStream() {
    _sub?.cancel();
    _sub = null;
    _watchdog?.cancel();
  }

  @override
  void dispose() {
    _stopStream();
    _ticker?.cancel();
    _flushTimer?.cancel();
    _pullTimer?.cancel();
    super.dispose();
  }
}

bool _isToday(DateTime d) {
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

String _hm(DateTime d) =>
    '${(d.hour % 12 == 0 ? 12 : d.hour % 12)}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';

String fmtDuration(Duration d) => '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
