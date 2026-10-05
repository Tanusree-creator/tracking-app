import 'package:geolocator/geolocator.dart';

enum LocationIssue { servicesDisabled, denied, deniedForever }

class LocationException implements Exception {
  final LocationIssue issue;
  const LocationException(this.issue);

  String get message => switch (issue) {
        LocationIssue.servicesDisabled => 'Location services are turned off. Enable GPS to share your location.',
        LocationIssue.denied => 'Location permission was denied.',
        LocationIssue.deniedForever => 'Location permission is permanently denied. Enable it in system settings.',
      };
}

class LocationService {
  /// Throws [LocationException] if location can't be used.
  static Future<void> ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationIssue.servicesDisabled);
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) throw const LocationException(LocationIssue.denied);
    if (perm == LocationPermission.deniedForever) {
      throw const LocationException(LocationIssue.deniedForever);
    }
  }

  /// Position stream backed by an Android foreground service so tracking continues in background.
  static Stream<Position> stream() => Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          intervalDuration: const Duration(seconds: 10),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'FieldFlow',
            notificationText: 'Sharing your live location',
            enableWakeLock: true,
          ),
        ),
      );

  static double distanceM(double lat1, double lng1, double lat2, double lng2) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);

  static Future<void> openSettings() => Geolocator.openAppSettings();
}
