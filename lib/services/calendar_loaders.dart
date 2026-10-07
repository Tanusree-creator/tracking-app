import '../models/models.dart';
import '../models/office_models.dart';
import 'api.dart';

DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);

/// One calendar item per day of a leave (so every day of it shows on the grid).
Iterable<DayItem> leaveDays(LeaveRequest l, DateTime from, DateTime to, {String? who}) sync* {
  for (var d = l.from; !d.isAfter(l.to); d = DateTime(d.year, d.month, d.day + 1)) {
    if (d.isBefore(_d(from)) || d.isAfter(_d(to))) continue;
    yield DayItem(
      DayKind.leave,
      who == null ? 'On leave' : '$who on leave',
      l.approved ? 'Approved' : 'Waiting for approval',
      d,
      done: l.approved, // approved leave = marked absent
      who: who,
    );
  }
}

DayItem followUpItem(FollowUp f, {String? who}) => DayItem(
      f.isCall ? DayKind.call : DayKind.visit,
      f.org.isEmpty ? f.name : '${f.name} · ${f.org}',
      f.purpose,
      f.remindAt,
      done: f.done,
      who: who,
    );

/// Admin: everyone's visits, calls, office tasks and leave.
Future<List<DayItem>> adminCalendarItems(DateTime from, DateTime to, [String? userId]) async {
  final out = <DayItem>[];
  final cal = await Api.adminCalendar(from, to, userId);
  for (final l in (cal['leaves'] as List).cast<Map<String, dynamic>>()) {
    out.addAll(leaveDays(LeaveRequest.fromRemote(l), from, to, who: l['user_name'] as String?));
  }
  for (final f in (cal['follow_ups'] as List).cast<Map<String, dynamic>>()) {
    out.add(followUpItem(FollowUp.fromRemote(f), who: f['user_name'] as String?));
  }
  for (final t in (cal['office_tasks'] as List).cast<Map<String, dynamic>>()) {
    final task = OfficeTask.fromRemote(t);
    out.add(DayItem(DayKind.task, task.title, task.note, task.due, done: task.done, who: t['user_name'] as String?));
  }
  try {
    final visits = await Api.adminTasksRange(from, to);
    for (final v in visits) {
      if (userId != null) continue; // admin_tasks_range is not filtered per user
      out.add(DayItem(DayKind.visit, v['title'] as String, (v['location'] ?? '') as String,
          DateTime.parse(v['scheduled_time'] as String).toLocal(),
          done: v['status'] == 'completed', who: v['user_name'] as String?));
    }
  } catch (_) {}
  return out;
}

/// Employee: my own visits, tasks, follow-ups and leave.
List<DayItem> myCalendarItems({required List<Visit> visits, List<OfficeTask> tasks = const [], List<FollowUp> followUps = const [], List<LeaveRequest> leaves = const [], required DateTime from, required DateTime to}) => [
      for (final v in visits)
        if (!v.scheduledTime.isBefore(from) && v.scheduledTime.isBefore(to))
          DayItem(DayKind.visit, v.title, v.location, v.scheduledTime, done: v.status == VisitStatus.completed),
      for (final t in tasks)
        if (!t.due.isBefore(from) && t.due.isBefore(to)) DayItem(DayKind.task, t.title, t.note, t.due, done: t.done),
      for (final f in followUps)
        if (!f.remindAt.isBefore(from) && f.remindAt.isBefore(to)) followUpItem(f),
      for (final l in leaves) ...leaveDays(l, from, to),
    ];
