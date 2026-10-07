import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show IconData, Icons;

import '../l10n/l10n.dart';

enum AccessStatus { pending, approved, rejected }

enum DutyStatus { offDuty, onDuty, onBreak }

enum VisitStatus { pending, inProgress, completed }

enum AlertAudience { admin, employee }

/// What came out of a visit (chosen when the employee closes it).
enum VisitOutcome {
  ordered('Books ordered', Icons.shopping_bag_outlined),
  sampleGiven('Samples given', Icons.menu_book_outlined),
  followUp('Follow up later', Icons.event_repeat),
  notInterested('Not interested', Icons.thumb_down_alt_outlined);

  final String _label;
  final IconData icon;
  const VisitOutcome(this._label, this.icon);

  String get label => _label.tr;

  /// Orders and samples are counted in copies.
  bool get hasCopies => this == ordered || this == sampleGiven;

  static VisitOutcome? from(String? s) => values.where((o) => o.name == s).firstOrNull;
}

AccessStatus accessStatusFrom(String? s) => AccessStatus.values
    .firstWhere((e) => e.name == s, orElse: () => AccessStatus.pending);

class Employee extends Equatable {
  final String id;
  final String name;
  final String email;
  final String title; // Junior / Field / Senior Technician
  final String district;
  final String? phone;
  final AccessStatus access;
  final DutyStatus status;
  final bool isDemo;
  final double? lat;
  final double? lng;
  final DateTime? lastSeen;
  final DateTime? shiftStart;
  final int unread;
  final String staffType; // 'field' (marketing, GPS tracked) or 'office' (in-house)

  const Employee({
    required this.id,
    required this.name,
    required this.email,
    this.title = 'Field Technician',
    this.district = 'East District',
    this.phone,
    this.access = AccessStatus.approved,
    this.status = DutyStatus.offDuty,
    this.isDemo = false,
    this.lat,
    this.lng,
    this.lastSeen,
    this.shiftStart,
    this.unread = 0,
    this.staffType = 'field',
  });

  bool get isOffice => staffType == 'office';

  /// Row from `admin_live`.
  factory Employee.fromLive(Map<String, dynamic> j) {
    final lp = j['last_point'] as Map?;
    final open = j['shift_start'] != null;
    return Employee(
      id: j['id'] as String,
      name: j['name'] as String,
      email: j['email'] as String,
      title: (j['role_title'] ?? 'Field Technician') as String,
      district: (j['district'] ?? 'East District') as String,
      phone: j['phone'] as String?,
      status: !open ? DutyStatus.offDuty : (j['on_break'] == true ? DutyStatus.onBreak : DutyStatus.onDuty),
      lat: (lp?['lat'] as num?)?.toDouble(),
      lng: (lp?['lng'] as num?)?.toDouble(),
      lastSeen: lp == null ? null : DateTime.parse(lp['at'] as String).toLocal(),
      shiftStart: open ? DateTime.parse(j['shift_start'] as String).toLocal() : null,
      unread: (j['unread'] as num?)?.toInt() ?? 0,
      staffType: (j['staff_type'] ?? 'field') as String,
    );
  }

  /// Seen in the last 2 minutes.
  bool get isLive => lastSeen != null && DateTime.now().difference(lastSeen!) < const Duration(minutes: 2);

  factory Employee.fromRemote(Map<String, dynamic> j) => Employee(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        title: (j['role_title'] ?? 'Field Technician') as String,
        district: (j['district'] ?? 'East District') as String,
        access: accessStatusFrom(j['status'] as String?),
        staffType: (j['staff_type'] ?? 'field') as String,
      );

  String get initials => name
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  @override
  List<Object?> get props => [id, name, email, title, district, phone, access, status, lat, lng, lastSeen, unread, staffType];
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

  factory Shift.fromRemote(Map<String, dynamic> j) => Shift(
        id: j['id'] as String,
        start: DateTime.parse(j['start'] as String).toLocal(),
        end: j['end'] == null ? null : DateTime.parse(j['end'] as String).toLocal(),
        breaks: ((j['breaks'] ?? []) as List)
            .map((b) => ShiftBreak(DateTime.parse(b['start'] as String).toLocal(),
                b['end'] == null ? null : DateTime.parse(b['end'] as String).toLocal()))
            .toList(),
      );

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
  double? lat;
  double? lng;
  bool byAdmin;
  bool hasPhoto;
  VisitOutcome? outcome;
  String? outcomeNote;
  int? copies;
  String? photoB64; // only kept locally until the server confirms the upload
  bool synced;

  Visit({
    required this.id,
    required this.title,
    required this.location,
    required this.scheduledTime,
    this.status = VisitStatus.pending,
    this.startedAt,
    this.completedAt,
    this.lat,
    this.lng,
    this.byAdmin = false,
    this.hasPhoto = false,
    this.outcome,
    this.outcomeNote,
    this.copies,
    this.photoB64,
    this.synced = false,
  });

  factory Visit.fromRemote(Map<String, dynamic> j) => Visit(
        id: j['id'] as String,
        title: j['title'] as String,
        location: (j['location'] ?? '') as String,
        scheduledTime: DateTime.parse(j['scheduled_time'] as String).toLocal(),
        status: VisitStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => VisitStatus.pending),
        startedAt: j['started_at'] == null ? null : DateTime.parse(j['started_at'] as String).toLocal(),
        completedAt: j['completed_at'] == null ? null : DateTime.parse(j['completed_at'] as String).toLocal(),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        byAdmin: j['by_admin'] == true,
        hasPhoto: j['has_photo'] == true,
        outcome: VisitOutcome.from(j['outcome'] as String?),
        outcomeNote: j['outcome_note'] as String?,
        copies: (j['copies'] as num?)?.toInt(),
        synced: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'location': location,
        'scheduledTime': scheduledTime.toIso8601String(),
        'status': status.name,
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'byAdmin': byAdmin,
        'hasPhoto': hasPhoto,
        'outcome': outcome?.name,
        'outcomeNote': outcomeNote,
        'copies': copies,
        'photo': photoB64,
        'synced': synced,
      };

  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
        id: j['id'],
        title: j['title'],
        location: j['location'],
        scheduledTime: DateTime.parse(j['scheduledTime']),
        status: VisitStatus.values.firstWhere((s) => s.name == j['status']),
        startedAt: j['startedAt'] == null ? null : DateTime.parse(j['startedAt']),
        completedAt: j['completedAt'] == null ? null : DateTime.parse(j['completedAt']),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        byAdmin: j['byAdmin'] == true,
        hasPhoto: j['hasPhoto'] == true,
        outcome: VisitOutcome.from(j['outcome'] as String?),
        outcomeNote: j['outcomeNote'] as String?,
        copies: (j['copies'] as num?)?.toInt(),
        photoB64: j['photo'] as String?,
        synced: j['synced'] == true,
      );
}

class LocationPoint {
  final double lat;
  final double lng;
  final DateTime timestamp;
  final double? accuracy;
  final double? speed;
  final double? heading;
  const LocationPoint(this.lat, this.lng, this.timestamp, {this.accuracy, this.speed, this.heading});

  Map<String, dynamic> toJson() =>
      {'lat': lat, 'lng': lng, 't': timestamp.toIso8601String(), 'acc': accuracy, 'speed': speed, 'heading': heading};
  factory LocationPoint.fromJson(Map<String, dynamic> j) => LocationPoint(j['lat'], j['lng'], DateTime.parse(j['t']),
      accuracy: (j['acc'] as num?)?.toDouble(), speed: (j['speed'] as num?)?.toDouble(), heading: (j['heading'] as num?)?.toDouble());

  /// Row from `my_route` / `admin_route`.
  factory LocationPoint.fromRemote(Map<String, dynamic> j) => LocationPoint(
      (j['lat'] as num).toDouble(), (j['lng'] as num).toDouble(), DateTime.parse(j['at'] as String).toLocal(),
      accuracy: (j['acc'] as num?)?.toDouble());

  /// Upload payload for `add_location_points`.
  Map<String, dynamic> toUpload() => {
        'lat': lat,
        'lng': lng,
        'acc': accuracy,
        'speed': speed,
        'heading': heading,
        'at': timestamp.toUtc().toIso8601String(),
      };
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

class ChatMessage {
  final String id;
  final bool fromAdmin;
  final String body;
  final bool isSystem;
  final DateTime at;
  final String kind; // text | image | voice (the photo / audio itself is fetched on demand)
  const ChatMessage(this.id, this.fromAdmin, this.body, this.isSystem, this.at, {this.kind = 'text'});

  bool get isImage => kind == 'image';
  bool get isVoice => kind == 'voice';

  factory ChatMessage.fromRemote(Map<String, dynamic> j) => ChatMessage(j['id'] as String, j['from_admin'] == true,
      j['body'] as String, j['is_system'] == true, DateTime.parse(j['created_at'] as String).toLocal(),
      kind: (j['kind'] ?? 'text') as String);
}
