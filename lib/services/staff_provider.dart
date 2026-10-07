import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../models/office_models.dart';
import 'api.dart';
import 'app_notifications_provider.dart';

/// Data every employee needs besides GPS tracking: leave, announcements, and (office staff) tasks + follow-ups.
class StaffProvider extends ChangeNotifier {
  final AppNotificationsProvider _alerts;
  StaffProvider(this._alerts);

  List<OfficeTask> tasks = [];
  List<FollowUp> followUps = [];
  List<LeaveRequest> leaves = [];
  List<Announcement> announcements = [];
  bool loading = false;
  String? error;
  bool _office = false;

  Timer? _poll;
  Timer? _tick;
  final _reminded = <String>{};
  final Map<String, String> _leaveStatus = {};
  String? _lastAnnouncement;
  bool _first = true;

  /// Start for the signed-in employee; [office] also loads tasks and follow-ups.
  Future<void> start({required bool office}) async {
    _office = office;
    _first = true;
    try {
      _lastAnnouncement = (await SharedPreferences.getInstance()).getString('last_announcement');
    } catch (_) {}
    await refresh();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 25), (_) => refresh(silent: true));
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => _checkReminders());
  }

  void stop() {
    _poll?.cancel();
    _tick?.cancel();
    _poll = _tick = null;
    tasks = [];
    followUps = [];
    leaves = [];
    announcements = [];
    _reminded.clear();
    _leaveStatus.clear();
    error = null;
    notifyListeners();
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      leaves = (await Api.myLeaves()).map(LeaveRequest.fromRemote).toList();
      announcements = (await Api.myAnnouncements()).map(Announcement.fromRemote).toList();
      if (_office) {
        tasks = (await Api.myOfficeTasks()).map(OfficeTask.fromRemote).toList();
        followUps = (await Api.myFollowUps()).map(FollowUp.fromRemote).toList();
      }
      _announceChanges();
      error = null;
    } catch (e) {
      if (!silent) error = '${e.toString().replaceFirst('Exception: ', '')}\n(Run supabase/007_office_leaves_announcements.sql if you have not yet.)';
    }
    loading = false;
    notifyListeners();
    _checkReminders();
  }

  void _announceChanges() {
    // leave decisions
    for (final l in leaves) {
      final old = _leaveStatus[l.id];
      _leaveStatus[l.id] = l.status;
      if (!_first && old == 'pending' && !l.pending) {
        _alerts.add(l.approved ? 'Leave approved' : 'Leave rejected', _range(l.from, l.to), AlertAudience.employee);
      }
    }
    // new announcements
    if (announcements.isNotEmpty) {
      final newest = announcements.first.id;
      if (!_first && _lastAnnouncement != newest) {
        for (final a in announcements.takeWhile((a) => a.id != _lastAnnouncement).toList().reversed) {
          _alerts.add(a.title, a.body, AlertAudience.employee);
        }
      }
      if (_lastAnnouncement != newest) {
        _lastAnnouncement = newest;
        SharedPreferences.getInstance().then((p) => p.setString('last_announcement', newest)).catchError((_) => true);
      }
    }
    _first = false;
  }

  static String _range(DateTime a, DateTime b) =>
      a == b ? '${a.day}/${a.month}/${a.year}' : '${a.day}/${a.month} – ${b.day}/${b.month}/${b.year}';

  /// Pop a reminder when a call or visit is due (checked while the app is running).
  void _checkReminders() {
    final now = DateTime.now();
    for (final f in followUps) {
      if (f.done || _reminded.contains(f.id)) continue;
      final diff = f.remindAt.difference(now);
      if (diff <= const Duration(minutes: 5) && diff > const Duration(hours: -6)) {
        _reminded.add(f.id);
        _alerts.add('${f.isCall ? 'Call'.tr : 'Visit'.tr}: ${f.name}', [if (f.org.isNotEmpty) f.org, if (f.purpose.isNotEmpty) f.purpose].join(' · '), AlertAudience.employee);
      }
    }
  }

  int get pendingTasks => tasks.where((t) => !t.done).length;
  int get dueCalls => followUps.where((f) => !f.done && f.remindAt.isBefore(DateTime.now().add(const Duration(days: 1)))).length;

  /// Approved leave covering [day] (used to mark that day absent).
  LeaveRequest? approvedLeaveOn(DateTime day) => leaves.where((l) => l.approved && l.covers(day)).firstOrNull;

  // ── office tasks ─────────────────────────────────────────────────────────
  Future<void> saveTask(OfficeTask t, {bool isNew = false}) async {
    if (isNew) tasks.insert(0, t);
    notifyListeners();
    await Api.syncOfficeTask({'id': t.id, 'title': t.title, 'note': t.note, 'due': t.due.toUtc().toIso8601String(), 'status': t.status});
    notifyListeners();
  }

  Future<void> addTask(String title, String note, DateTime due) =>
      saveTask(OfficeTask(id: const Uuid().v4(), title: title, note: note, due: due), isNew: true);

  Future<void> setTaskStatus(OfficeTask t, String status) {
    t.status = status;
    t.completedAt = status == 'completed' ? (t.completedAt ?? DateTime.now()) : null;
    return saveTask(t);
  }

  Future<void> deleteTask(OfficeTask t) async {
    tasks.remove(t);
    notifyListeners();
    await Api.deleteOfficeTask(t.id);
  }

  // ── follow-ups ───────────────────────────────────────────────────────────
  Future<void> saveFollowUp(FollowUp f, {bool isNew = false}) async {
    if (isNew) followUps.add(f);
    followUps.sort((a, b) => a.remindAt.compareTo(b.remindAt));
    _reminded.remove(f.id);
    notifyListeners();
    await Api.syncFollowUp({
      'id': f.id,
      'name': f.name,
      'org': f.org,
      'phone': f.phone,
      'purpose': f.purpose,
      'kind': f.kind,
      'remind': f.remindAt.toUtc().toIso8601String(),
      'status': f.status,
      'result': f.result,
    });
    notifyListeners();
  }

  Future<void> deleteFollowUp(FollowUp f) async {
    followUps.remove(f);
    notifyListeners();
    await Api.deleteFollowUp(f.id);
  }

  // ── leave ────────────────────────────────────────────────────────────────
  Future<void> requestLeave(DateTime from, DateTime to, String reason) async {
    await Api.requestLeave(from, to, reason);
    await refresh(silent: true);
  }

  Future<void> cancelLeave(LeaveRequest l) async {
    await Api.cancelLeave(l.id);
    await refresh(silent: true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }
}
