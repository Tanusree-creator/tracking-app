import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'notification_service.dart';

class AppNotificationsProvider extends ChangeNotifier {
  final List<AppAlert> _alerts = [];
  bool pushEnabled = true;

  AppNotificationsProvider() {
    final now = DateTime.now();
    AppAlert a(String t, String b, int minsAgo) => AppAlert(
          id: const Uuid().v4(),
          title: t,
          body: b,
          audience: AlertAudience.admin,
          time: now.subtract(Duration(minutes: minsAgo)),
        );
    _alerts.addAll([
      a('Brent Moyer started shift', 'Clocked in at East District depot', 12),
      a('Marcus Vance completed job #1042', 'HVAC filter swap at Harbor Street Clinic', 25),
      a('Elena Cross checked in at site', 'Lincoln Elementary', 41),
      a('Dana Ruiz has not checked in today', 'Shift was scheduled for 8:00 AM', 70),
      a('Employee missed a scheduled visit', 'Tom Baxter – Fire panel test', 95),
    ]);
  }

  List<AppAlert> forAudience(AlertAudience audience) =>
      _alerts.where((a) => a.audience == audience).toList()..sort((a, b) => b.time.compareTo(a.time));

  AppAlert? latestUnread(AlertAudience audience) {
    final list = forAudience(audience).where((a) => !a.read);
    return list.isEmpty ? null : list.first;
  }

  void add(String title, String body, AlertAudience audience, {bool notify = true}) {
    _alerts.add(AppAlert(
        id: const Uuid().v4(), title: title, body: body, audience: audience, time: DateTime.now()));
    if (notify && pushEnabled) NotificationService.instance.show(title, body);
    notifyListeners();
  }

  void markRead(AppAlert alert) {
    alert.read = true;
    notifyListeners();
  }

  void setPush(bool v) {
    pushEnabled = v;
    notifyListeners();
  }
}
