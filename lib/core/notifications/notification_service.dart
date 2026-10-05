import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local, scheduled "meeting in 1 hour" reminders.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationDetails(
    'visit_reminders',
    'Visit reminders',
    channelDescription: 'Reminders one hour before a client meeting',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _details = NotificationDetails(
    android: _channel,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  /// Android 13+ / iOS prompt. Returns whether notifications are allowed.
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final a = await android?.requestNotificationsPermission();
    final i = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return (a ?? i ?? true);
  }

  /// Schedules a reminder [lead] before [start]. Skips it if already past.
  Future<void> scheduleVisitReminder({
    required String visitId,
    required DateTime start,
    required String title,
    required String body,
    Duration lead = const Duration(hours: 1),
  }) async {
    final fireAt = tz.TZDateTime.from(start.subtract(lead), tz.local);
    if (fireAt.isBefore(tz.TZDateTime.now(tz.local))) return;
    try {
      await _plugin.zonedSchedule(
        id: _idFor(visitId),
        title: title,
        body: body,
        scheduledDate: fireAt,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: visitId,
      );
    } catch (e) {
      debugPrint('Could not schedule reminder for $visitId: $e');
    }
  }

  Future<void> cancelVisitReminder(String visitId) =>
      _plugin.cancel(id: _idFor(visitId));

  Future<void> cancelAll() => _plugin.cancelAll();

  int _idFor(String visitId) => visitId.hashCode & 0x7fffffff;
}
