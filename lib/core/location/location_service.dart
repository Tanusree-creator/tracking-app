import 'dart:io';

import 'package:geolocator/geolocator.dart';

enum LocationAccess { granted, denied, deniedForever, serviceOff }

class LocationService {
  Future<LocationAccess> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return switch (perm) {
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      LocationPermission.denied => LocationAccess.denied,
      _ => LocationAccess.granted,
    };
  }

  Future<Position> current() => Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

  /// Live stream that keeps running in the background while a shift is active.
  Stream<Position> trackingStream() {
    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Shift in progress',
          notificationText: 'FieldFlow is recording your route.',
          enableWakeLock: true,
        ),
      );
    } else if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}
