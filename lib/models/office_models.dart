import 'package:flutter/material.dart' show IconData, Icons;

DateTime _dt(dynamic v) => DateTime.parse(v as String).toLocal();
DateTime _date(dynamic v) {
  final d = DateTime.parse(v as String);
  return DateTime(d.year, d.month, d.day);
}

/// A task for office staff: no location, just a title, a note and a due time.
class OfficeTask {
  final String id;
  String title;
  String note;
  DateTime due;
  String status; // pending | inProgress | completed
  final bool byAdmin;
  final String? userName; // admin views only
  DateTime? completedAt;

  OfficeTask({required this.id, required this.title, this.note = '', required this.due, this.status = 'pending', this.byAdmin = false, this.userName, this.completedAt});

  bool get done => status == 'completed';
  bool get completedToday {
    final c = completedAt;
    final n = DateTime.now();
    return c != null && c.year == n.year && c.month == n.month && c.day == n.day;
  }

  factory OfficeTask.fromRemote(Map<String, dynamic> j) => OfficeTask(
        id: j['id'] as String,
        title: j['title'] as String,
        note: (j['note'] ?? '') as String,
        due: _dt(j['due_at']),
        status: j['status'] as String,
        byAdmin: j['by_admin'] == true,
        userName: j['user_name'] as String?,
        completedAt: j['completed_at'] == null ? null : _dt(j['completed_at']),
      );
}

/// A person or school to call (or visit later) at a set date and time.
class FollowUp {
  final String id;
  String name;
  String org;
  String phone;
  String purpose;
  String kind; // call | visit
  DateTime remindAt;
  String status; // pending | done
  String result;
  final String? userName;

  FollowUp({
    required this.id,
    required this.name,
    this.org = '',
    this.phone = '',
    this.purpose = '',
    this.kind = 'call',
    required this.remindAt,
    this.status = 'pending',
    this.result = '',
    this.userName,
  });

  bool get done => status == 'done';
  bool get isCall => kind == 'call';
  bool get overdue => !done && remindAt.isBefore(DateTime.now());

  factory FollowUp.fromRemote(Map<String, dynamic> j) => FollowUp(
        id: j['id'] as String,
        name: j['name'] as String,
        org: (j['org'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        purpose: (j['purpose'] ?? '') as String,
        kind: (j['kind'] ?? 'call') as String,
        remindAt: _dt(j['remind_at']),
        status: (j['status'] ?? 'pending') as String,
        result: (j['result'] ?? '') as String,
        userName: j['user_name'] as String?,
      );
}

class LeaveRequest {
  final String id;
  final DateTime from; // dates only (midnight)
  final DateTime to;
  final String reason;
  final String status; // pending | approved | rejected
  final String? userId;
  final String? userName;
  final String? staffType;
  final DateTime? decidedAt;

  const LeaveRequest({
    required this.id,
    required this.from,
    required this.to,
    this.reason = '',
    this.status = 'pending',
    this.userId,
    this.userName,
    this.staffType,
    this.decidedAt,
  });

  bool get approved => status == 'approved';
  bool get pending => status == 'pending';
  int get days => to.difference(from).inDays + 1;

  bool covers(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(from) && !x.isAfter(to);
  }

  factory LeaveRequest.fromRemote(Map<String, dynamic> j) => LeaveRequest(
        id: j['id'] as String,
        from: _date(j['from']),
        to: _date(j['to']),
        reason: (j['reason'] ?? '') as String,
        status: j['status'] as String,
        userId: j['user_id'] as String?,
        userName: j['user_name'] as String?,
        staffType: j['staff_type'] as String?,
        decidedAt: j['decided_at'] == null ? null : _dt(j['decided_at']),
      );
}

class Announcement {
  final String id;
  final String title;
  final String body;
  final String? image; // base64 JPEG
  final String audience;
  final DateTime at;

  const Announcement({required this.id, required this.title, required this.body, this.image, this.audience = 'all', required this.at});

  factory Announcement.fromRemote(Map<String, dynamic> j) => Announcement(
        id: j['id'] as String,
        title: j['title'] as String,
        body: (j['body'] ?? '') as String,
        image: j['image'] as String?,
        audience: (j['audience'] ?? 'all') as String,
        at: _dt(j['created_at']),
      );
}

/// What a day in the calendar is about; decides the picture, colour and icon of its card.
enum DayKind {
  holiday('Holiday', Icons.celebration, 0xFF1D6FFF),
  leave('Leave', Icons.beach_access, 0xFFE5484D),
  call('Call', Icons.phone_in_talk, 0xFF7C4DFF),
  visit('Visit', Icons.storefront, 0xFF1FAF63),
  task('Task', Icons.task_alt, 0xFFE59A00);

  final String label;
  final IconData icon;
  final int argb;
  const DayKind(this.label, this.icon, this.argb);
}

/// One entry on a calendar day.
class DayItem {
  final DayKind kind;
  final String title;
  final String subtitle;
  final DateTime at;
  final bool done;
  final String? who;
  final bool approx;

  const DayItem(this.kind, this.title, this.subtitle, this.at, {this.done = false, this.who, this.approx = false});
}
