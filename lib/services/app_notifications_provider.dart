import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import 'api.dart';
import 'notification_service.dart';

class AppNotificationsProvider extends ChangeNotifier {
  final List<AppAlert> _alerts = [];
  bool pushEnabled = true;
  Timer? _poll;
  DateTime _since = DateTime.now().toUtc();
  final _seen = <String>{};

  List<AppAlert> forAudience(AlertAudience audience) =>
      _alerts.where((a) => a.audience == audience).toList()..sort((a, b) => b.time.compareTo(a.time));

  AppAlert? latestUnread(AlertAudience audience) {
    final list = forAudience(audience).where((a) => !a.read);
    return list.isEmpty ? null : list.first;
  }

  void add(String title, String body, AlertAudience audience, {bool notify = true}) {
    title = title.tr;
    body = body.tr;
    _alerts.add(AppAlert(id: const Uuid().v4(), title: title, body: body, audience: audience, time: DateTime.now()));
    if (notify && pushEnabled) NotificationService.instance.show(title, body);
    notifyListeners();
  }

  /// Admin: poll the server for events (shifts, tasks created/closed, messages, face checks)
  /// and show each one as a pop-up banner + system notification.
  void startAdminPolling() {
    _poll?.cancel();
    _since = DateTime.now().toUtc().subtract(const Duration(hours: 12));
    _pollOnce(initial: true);
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _pollOnce());
  }

  void stopAdminPolling() {
    _poll?.cancel();
    _poll = null;
    _alerts.removeWhere((a) => a.audience == AlertAudience.admin);
    _seen.clear();
    notifyListeners();
  }

  Future<void> _pollOnce({bool initial = false}) async {
    try {
      final rows = await Api.adminEventsSince(_since);
      if (rows.isEmpty) return;
      for (final r in rows.reversed) {
        final id = r['id'] as String;
        if (!_seen.add(id)) continue;
        final at = DateTime.parse(r['created_at'] as String).toLocal();
        final fresh = !initial || DateTime.now().difference(at) < const Duration(minutes: 2);
        _alerts.add(AppAlert(
          id: id,
          title: (r['title'] as String).tr,
          body: ((r['body'] ?? '') as String).tr,
          audience: AlertAudience.admin,
          time: at,
          read: !fresh, // old events go to the list without a banner
        ));
        if (fresh && pushEnabled) NotificationService.instance.show(r['title'] as String, (r['body'] ?? '') as String);
        if (at.toUtc().isAfter(_since)) _since = at.toUtc();
      }
      notifyListeners();
    } catch (_) {/* offline or 004 not run: try again next tick */}
  }

  void markRead(AppAlert alert) {
    alert.read = true;
    notifyListeners();
  }

  void setPush(bool v) {
    pushEnabled = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
