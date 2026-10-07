import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/access_provider.dart';
import '../services/staff_provider.dart';
import '../services/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/tn_calendar.dart';
import 'announcements_screen.dart';
import 'chat_screens.dart';
import 'edit_profile_screen.dart';
import 'follow_ups_screen.dart';
import 'leave_screen.dart';
import 'profile_screen.dart' show AddPhotoBanner;
import 'staff_calendar.dart';
import 'office_tasks_screen.dart';

/// Dashboard for office (in-house) staff: tasks and calls for today. No clock-in or GPS tracking.
class OfficeHomeScreen extends StatelessWidget {
  final ValueChanged<int> goToTab;
  const OfficeHomeScreen({super.key, required this.goToTab});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final sp = context.watch<StaffProvider>();
    final tr = context.watch<TrackingProvider>();
    final me = access.me!;
    final now = DateTime.now();
    bool today(DateTime d) => d.year == now.year && d.month == now.month && d.day == now.day;
    final todaysTasks = sp.tasks.where((t) => !t.done && (today(t.due) || t.due.isBefore(now))).toList()..sort((a, b) => a.due.compareTo(b.due));
    final todaysCalls = sp.followUps.where((f) => !f.done && (today(f.remindAt) || f.remindAt.isBefore(now))).toList();
    final doneToday = sp.tasks.where((t) => t.done && t.completedToday).length;
    final pendingLeave = sp.leaves.where((l) => l.pending).length;
    final unreadAnn = sp.announcements.isEmpty ? 0 : 0;
    final first = me.name.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${'Hi'.tr}, $first', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(DateFormat('EEEE, d MMMM', L10n.current.name).format(now), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Announcements'.tr,
            icon: Badge(isLabelVisible: unreadAnn > 0, label: Text('$unreadAnn'), child: const Icon(Icons.campaign_outlined)),
            onPressed: () => Navigator.of(context).push(slideRoute(const AnnouncementsScreen())),
          ),
          IconButton(
            tooltip: 'Chat with admin'.tr,
            icon: Badge(isLabelVisible: tr.unreadChat > 0, label: Text('${tr.unreadChat}'), child: const Icon(Icons.chat_bubble_outline)),
            onPressed: () => Navigator.of(context).push(slideRoute(const EmployeeChatScreen())),
          ),
          Padding(padding: const EdgeInsets.only(right: 12, left: 4), child: UserAvatar(photo: access.myAvatar, initials: me.initials, radius: 17)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: sp.refresh,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: Sp.screen, children: [
          if (access.myAvatar == null) ...[
            AddPhotoBanner(onTap: () => Navigator.of(context).push(slideRoute(const EditProfileScreen()))),
            const SizedBox(height: 12),
          ],
          TnCalendarCard(onTap: () => openStaffCalendar(context)).enter(),
          const SizedBox(height: Sp.l),
          StatGrid([
            StatTile(icon: Icons.task_alt, value: '${sp.pendingTasks}', label: 'Open tasks'.tr, onTap: () => goToTab(1)),
            StatTile(icon: Icons.phone_in_talk, value: '${todaysCalls.length}', label: 'Calls due'.tr, color: const Color(0xFF7C4DFF), onTap: () => goToTab(2)),
            StatTile(icon: Icons.check_circle_outline, value: '$doneToday', label: 'Done today'.tr, color: AppColors.green),
            StatTile(
              icon: Icons.beach_access,
              value: '$pendingLeave',
              label: 'Leave pending'.tr,
              color: AppColors.amber,
              onTap: () => Navigator.of(context).push(slideRoute(const LeaveScreen())),
            ),
          ]),
          const SizedBox(height: Sp.m),
          Row(children: [
            Expanded(child: _Quick(Icons.event_busy, 'Request leave', () => Navigator.of(context).push(slideRoute(const LeaveScreen())))),
            const SizedBox(width: Sp.m),
            Expanded(child: _Quick(Icons.campaign, 'Announcements', () => Navigator.of(context).push(slideRoute(const AnnouncementsScreen())))),
          ]),
          SectionTitle("Today's tasks".tr, trailing: TextButton(onPressed: () => showTaskSheet(context), child: Text('+ ${'Add'.tr}'))),
          if (sp.error != null)
            ErrorState(sp.error!.tr, sp.refresh)
          else if (todaysTasks.isEmpty)
            EmptyState(Icons.task_alt, 'Nothing due today. Add a task to plan your day.')
          else
            for (final (i, t) in todaysTasks.indexed) Padding(padding: const EdgeInsets.only(bottom: Sp.s), child: OfficeTaskCard(t).enter(i)),
          SectionTitle("Today's calls".tr, trailing: TextButton(onPressed: () => showFollowUpSheet(context), child: Text('+ ${'Add'.tr}'))),
          if (todaysCalls.isEmpty)
            EmptyState(Icons.phone_in_talk_outlined, 'No calls due today.')
          else
            for (final (i, f) in todaysCalls.indexed) Padding(padding: const EdgeInsets.only(bottom: Sp.s), child: FollowUpCard(f).enter(i)),
        ]),
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Quick(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.l, horizontal: Sp.m),
          child: Row(children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(width: Sp.s),
            Expanded(child: Text(label.tr, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 2)),
          ]),
        ),
      );
}
