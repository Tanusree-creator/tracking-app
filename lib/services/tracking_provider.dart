import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'app_notifications_provider.dart';
import 'demo_data.dart';
import 'location_service.dart';

class TrackingProvider extends ChangeNotifier {
  final AppNotificationsProvider _alerts;
  TrackingProvider(this._alerts);

  String? _userId;
  List<Shift> shifts = [];
  List<Visit> visits = [];
  List<LocationPoint> points = [];

  bool sharing = false;
  bool paused = false;
  bool signalLost = false;
  String? locationError;
  LocationIssue? locationIssue;

  StreamSubscription<Position>? _sub;
  Timer? _watchdog;
  Timer? _ticker;

  // ── lifecycle ──────────────────────────────────────────────────────────────
  Future<void> load(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tracking_$userId');
    if (raw == null) {
      visits = DemoData.seedVisits();
    } else {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      shifts = (j['shifts'] as List).map((e) => Shift.fromJson(e)).toList();
      visits = (j['visits'] as List).map((e) => Visit.fromJson(e)).toList();
      points = (j['points'] as List)
          .map((e) => LocationPoint.fromJson(e))
          .where((p) => _isToday(p.timestamp))
          .toList();
    }
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => notifyListeners());
    _checkMissedVisits();
    notifyListeners();
  }

  void reset() {
    _stopStream();
    _ticker?.cancel();
    _userId = null;
    shifts = [];
    visits = [];
    points = [];
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
      }),
    );
  }

  void _checkMissedVisits() {
    final now = DateTime.now();
    final missed = visits.where((v) =>
        v.status == VisitStatus.pending &&
        _isToday(v.scheduledTime) &&
        now.difference(v.scheduledTime) > const Duration(minutes: 30));
    if (missed.isNotEmpty) {
      _alerts.add('Missed visit reminder', '${missed.first.title} was scheduled for ${_hm(missed.first.scheduledTime)}.',
          AlertAudience.employee);
    }
  }

  // ── shift ──────────────────────────────────────────────────────────────────
  Shift? get openShift => shifts.where((s) => s.isOpen).firstOrNull;
  bool get clockedIn => openShift != null;
  bool get onBreak => openShift?.onBreak ?? false;

  void toggleShift() {
    final open = openShift;
    if (open == null) {
      shifts.add(Shift(id: const Uuid().v4(), start: DateTime.now()));
      _alerts.add('Shift started', 'You clocked in at ${_hm(DateTime.now())}.', AlertAudience.employee, notify: false);
    } else {
      if (open.onBreak) open.breaks.last.end = DateTime.now();
      open.end = DateTime.now();
      stopSharing();
      _alerts.add('Shift ended', 'Worked ${fmtDuration(open.worked)} today.', AlertAudience.employee, notify: false);
    }
    _save();
    notifyListeners();
  }

  void toggleBreak() {
    final open = openShift;
    if (open == null) return;
    if (open.onBreak) {
      open.breaks.last.end = DateTime.now();
    } else {
      open.breaks.add(ShiftBreak(DateTime.now()));
    }
    _save();
    notifyListeners();
  }

  // ── visits ─────────────────────────────────────────────────────────────────
  void addVisit(String title, String location, DateTime time) {
    visits.add(Visit(id: const Uuid().v4(), title: title, location: location, scheduledTime: time));
    visits.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    _save();
    notifyListeners();
  }

  void startVisit(Visit v) {
    v.status = VisitStatus.inProgress;
    v.startedAt = DateTime.now();
    _save();
    notifyListeners();
  }

  void completeVisit(Visit v) {
    v.status = VisitStatus.completed;
    v.completedAt = DateTime.now();
    _alerts.add('Visit completed', '${v.title} at ${v.location}', AlertAudience.employee, notify: false);
    _save();
    notifyListeners();
  }

  List<Visit> get todaysVisits => visits.where((v) => _isToday(v.scheduledTime)).toList();

  // ── stats ──────────────────────────────────────────────────────────────────
  Duration get hoursToday => shifts
      .where((s) => _isToday(s.start))
      .fold(Duration.zero, (a, s) => a + s.worked);

  int get visitsCompleted => visits.where((v) => v.status == VisitStatus.completed).length;

  int get jobsFinishedToday =>
      visits.where((v) => v.status == VisitStatus.completed && v.completedAt != null && _isToday(v.completedAt!)).length;

  double get distanceTodayKm {
    var m = 0.0;
    for (var i = 1; i < points.length; i++) {
      m += LocationService.distanceM(points[i - 1].lat, points[i - 1].lng, points[i].lat, points[i].lng);
    }
    return m / 1000;
  }

  // ── history ────────────────────────────────────────────────────────────────
  List<Shift> get closedShifts => shifts.where((s) => !s.isOpen).toList()..sort((a, b) => b.start.compareTo(a.start));

  Map<DateTime, double> get hoursByDay {
    final map = <DateTime, double>{};
    for (final s in shifts) {
      final d = DemoData.day(s.start);
      map[d] = (map[d] ?? 0) + s.worked.inMinutes / 60;
    }
    return map;
  }

  // ── location sharing ───────────────────────────────────────────────────────
  Future<void> startSharing() async {
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
    paused = false;
    signalLost = false;
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

  void togglePause() {
    paused = !paused;
    notifyListeners();
  }

  void _onPosition(Position p) {
    signalLost = false;
    _armWatchdog();
    if (!paused) {
      points.add(LocationPoint(p.latitude, p.longitude, DateTime.now()));
      if (points.length % 5 == 0) _save();
    }
    notifyListeners();
  }

  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 90), () {
      if (sharing) {
        signalLost = true;
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
