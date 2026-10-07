import 'package:latlong2/latlong.dart';

/// Map fallbacks used before any GPS fix exists. (The old fake roster was removed:
/// the admin app now shows real synced data.)
class DemoData {
  static const center = LatLng(41.8827, -87.6233);

  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
}
