import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../models/models.dart';

/// Deterministic demo data for the admin side (no field-data backend yet).
class DemoData {
  static const center = LatLng(41.8827, -87.6233);

  static const employees = <Employee>[
    Employee(id: 'demo-brent', name: 'Brent Moyer', email: 'brent@fieldflow.demo', title: 'Senior Technician', district: 'East District', status: DutyStatus.onDuty, isDemo: true),
    Employee(id: 'demo-marcus', name: 'Marcus Vance', email: 'marcus@fieldflow.demo', title: 'Field Technician', district: 'East District', status: DutyStatus.onDuty, isDemo: true),
    Employee(id: 'demo-elena', name: 'Elena Cross', email: 'elena@fieldflow.demo', title: 'Field Technician', district: 'North District', status: DutyStatus.onDuty, isDemo: true),
    Employee(id: 'demo-dana', name: 'Dana Ruiz', email: 'dana@fieldflow.demo', title: 'Junior Technician', district: 'North District', status: DutyStatus.offDuty, isDemo: true),
    Employee(id: 'demo-priya', name: 'Priya Nair', email: 'priya@fieldflow.demo', title: 'Senior Technician', district: 'North District', status: DutyStatus.onBreak, isDemo: true),
    Employee(id: 'demo-caleb', name: 'Caleb Stone', email: 'caleb@fieldflow.demo', title: 'Junior Technician', district: 'East District', status: DutyStatus.onDuty, isDemo: true),
    Employee(id: 'demo-tom', name: 'Tom Baxter', email: 'tom@fieldflow.demo', title: 'Field Technician', district: 'East District', status: DutyStatus.offDuty, isDemo: true),
  ];

  static Random _rng(String id, DateTime d) =>
      Random(id.hashCode ^ (d.year * 10000 + d.month * 100 + d.day));

  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Hours worked by an employee on a day (0 on weekends / random absences).
  static double hours(String id, DateTime d) {
    if (d.weekday >= 6) return 0;
    if (day(d).isAfter(day(DateTime.now()))) return 0;
    final r = _rng(id, d);
    if (r.nextInt(10) == 0) return 0;
    return double.parse((5 + r.nextDouble() * 4).toStringAsFixed(1));
  }

  static int visitsDone(String id, DateTime d) => hours(id, d) == 0 ? 0 : 2 + _rng(id, d).nextInt(5);

  static double km(String id, DateTime d) =>
      hours(id, d) == 0 ? 0 : double.parse((8 + _rng(id, d).nextDouble() * 40).toStringAsFixed(1));

  static LatLng position(Employee e) {
    final r = Random(e.id.hashCode);
    return LatLng(center.latitude + (r.nextDouble() - .5) * .05, center.longitude + (r.nextDouble() - .5) * .07);
  }

  static List<AttendanceDay> month(String id, DateTime anyDayInMonth) {
    final n = DateUtils_daysIn(anyDayInMonth);
    return [
      for (var i = 1; i <= n; i++)
        AttendanceDay(DateTime(anyDayInMonth.year, anyDayInMonth.month, i),
            hours(id, DateTime(anyDayInMonth.year, anyDayInMonth.month, i))),
    ];
  }

  // ignore: non_constant_identifier_names
  static int DateUtils_daysIn(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

  static List<Visit> seedVisits() {
    final now = DateTime.now();
    DateTime at(int h, [int m = 0]) => DateTime(now.year, now.month, now.day, h, m);
    return [
      Visit(id: 'seed-1', title: 'Boiler inspection', location: 'Lincoln Elementary', scheduledTime: at(9)),
      Visit(id: 'seed-2', title: 'Job #1042 – HVAC filter swap', location: 'Harbor Street Clinic', scheduledTime: at(11, 30)),
      Visit(id: 'seed-3', title: 'Fire panel test', location: 'Oak Ridge Library', scheduledTime: at(14)),
    ];
  }
}
