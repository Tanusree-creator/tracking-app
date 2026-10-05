import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../providers.dart';

/// Reads upcoming visits and (re)schedules the "1 hour before" reminder.
/// Technicians get a plain reminder; admins get one naming the technician.
/// Call after login and whenever the home screen refreshes.
Future<void> syncVisitReminders(WidgetRef ref) async {
  final user = ref.read(authProvider);
  if (user == null) return;
  final db = ref.read(supabaseProvider);
  final notifier = ref.read(notificationServiceProvider);

  try {
    var query = db
        .from('visits')
        .select('id,client_name,start_at,employee_id')
        .gte('start_at', DateTime.now().toUtc().toIso8601String());
    if (!user.isAdmin) query = query.eq('employee_id', user.id);
    final visits = await query.order('start_at').limit(100);

    final names = <String, String>{};
    if (user.isAdmin) {
      for (final e in await db.from('employees').select('id,name')) {
        names[e['id'] as String] = (e['name'] ?? 'An employee') as String;
      }
    }

    await notifier.cancelAll();
    for (final v in visits) {
      final start = DateTime.parse(v['start_at'] as String).toLocal();
      final client = (v['client_name'] ?? 'the client') as String;
      final time = _hm(start);
      final who = names[v['employee_id']] ?? 'An employee';
      await notifier.scheduleVisitReminder(
        visitId: v['id'].toString(),
        start: start,
        title: user.isAdmin ? 'Upcoming client meeting' : 'Meeting in 1 hour',
        body: user.isAdmin
            ? '$who meets $client at $time. Check their status.'
            : 'You meet $client at $time. Head out soon.',
      );
    }
  } catch (e) {
    debugPrint('Reminder sync failed: $e');
  }
}

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
