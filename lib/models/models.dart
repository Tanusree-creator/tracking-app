import 'package:equatable/equatable.dart';

enum AccessStatus { pending, approved, rejected }

enum DutyStatus { offDuty, onDuty, onBreak }

enum VisitStatus { pending, inProgress, completed }

enum AlertAudience { admin, employee }

AccessStatus accessStatusFrom(String? s) => AccessStatus.values
    .firstWhere((e) => e.name == s, orElse: () => AccessStatus.pending);

class Employee extends Equatable {
  final String id;
  final String name;
  final String email;
  final String title; // Junior / Field / Senior Technician
  final String district;
  final AccessStatus access;
  final DutyStatus status;
  final bool isDemo;

  const Employee({
    required this.id,
    required this.name,
    required this.email,
    this.title = 'Field Technician',
    this.district = 'East District',
    this.access = AccessStatus.approved,
    this.status = DutyStatus.offDuty,
    this.isDemo = false,
  });

  factory Employee.fromRemote(Map<String, dynamic> j) => Employee(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        title: (j['role_title'] ?? 'Field Technician') as String,
        district: (j['district'] ?? 'East District') as String,
        access: accessStatusFrom(j['status'] as String?),
      );

  String get initials => name
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  @override
  List<Object?> get props => [id, name, email, title, district, access, status];
}

class AccessRequest extends Equatable {
  final Employee employee;
  final DateTime requestedAt;
  const AccessRequest(this.employee, this.requestedAt);
  @override
  List<Object?> get props => [employee, requestedAt];
}

class Shift {
  final String id;
  final DateTime start;
  DateTime? end;
  final List<ShiftBreak> breaks;

  Shift({required this.id, required this.start, this.end, List<ShiftBreak>? breaks})
      : breaks = breaks ?? [];

  bool get isOpen => end == null;
  bool get onBreak => breaks.isNotEmpty && breaks.last.end == null;

  Duration get worked {
    final total = (end ?? DateTime.now()).difference(start);
    final brk = breaks.fold<Duration>(Duration.zero, (a, b) => a + b.duration);
    final w = total - brk;
    return w.isNegative ? Duration.zero : w;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'breaks': breaks.map((b) => b.toJson()).toList(),
      };

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
        id: j['id'],
        start: DateTime.parse(j['start']),
        end: j['end'] == null ? null : DateTime.parse(j['end']),
        breaks: (j['breaks'] as List).map((b) => ShiftBreak.fromJson(b)).toList(),
      );
}

class ShiftBreak {
  final DateTime start;
  DateTime? end;
  ShiftBreak(this.start, [this.end]);
  Duration get duration => (end ?? DateTime.now()).difference(start);
  Map<String, dynamic> toJson() => {'start': start.toIso8601String(), 'end': end?.toIso8601String()};
  factory ShiftBreak.fromJson(Map<String, dynamic> j) =>
      ShiftBreak(DateTime.parse(j['start']), j['end'] == null ? null : DateTime.parse(j['end']));
}

class AttendanceDay {
  final DateTime date;
  final double hours;
  const AttendanceDay(this.date, this.hours);

  /// full >= 7h, partial > 0, absent == 0
  bool get isFull => hours >= 7;
  bool get isPartial => hours > 0 && hours < 7;
}

class Visit {
  final String id;
  String title;
  String location;
  DateTime scheduledTime;
  VisitStatus status;
  DateTime? startedAt;
  DateTime? completedAt;

  Visit({
    required this.id,
    required this.title,
    required this.location,
    required this.scheduledTime,
    this.status = VisitStatus.pending,
    this.startedAt,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'location': location,
        'scheduledTime': scheduledTime.toIso8601String(),
        'status': status.name,
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
        id: j['id'],
        title: j['title'],
        location: j['location'],
        scheduledTime: DateTime.parse(j['scheduledTime']),
        status: VisitStatus.values.firstWhere((s) => s.name == j['status']),
        startedAt: j['startedAt'] == null ? null : DateTime.parse(j['startedAt']),
        completedAt: j['completedAt'] == null ? null : DateTime.parse(j['completedAt']),
      );
}

class LocationPoint {
  final double lat;
  final double lng;
  final DateTime timestamp;
  const LocationPoint(this.lat, this.lng, this.timestamp);

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 't': timestamp.toIso8601String()};
  factory LocationPoint.fromJson(Map<String, dynamic> j) =>
      LocationPoint(j['lat'], j['lng'], DateTime.parse(j['t']));
}

class AppAlert {
  final String id;
  final String title;
  final String body;
  final AlertAudience audience;
  final DateTime time;
  bool read;
  AppAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.time,
    this.read = false,
  });
}
