import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _id = 0;

  Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _ready = false; // unsupported platform (e.g. desktop/web): in-app alerts still work
    }
  }

  Future<void> show(String title, String body) async {
    if (!_ready) return;
    await _plugin.show(
      id: _id++,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fieldflow_alerts',
          'Merit Publication Alerts',
          channelDescription: 'Missed visit and shift alerts',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
        ),
      ),
    );
  }
}
