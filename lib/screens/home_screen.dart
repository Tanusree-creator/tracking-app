import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/access_provider.dart';
import '../services/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';
import '../widgets/anim.dart';
import '../widgets/tn_calendar.dart';
import 'announcements_screen.dart';
import 'chat_screens.dart';
import 'leave_screen.dart';
import 'staff_calendar.dart';
import 'edit_profile_screen.dart';
import 'face_verify_screen.dart';
import 'profile_screen.dart' show AddPhotoBanner;
import 'finished_jobs_screen.dart';
import 'leaderboard_screen.dart';
import 'route_map_screen.dart';
import 'tasks_screen.dart';
import '../widgets/glass.dart';
import '../l10n/l10n.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = context.watch<TrackingProvider>();
    final access = context.watch<AccessProvider>();
    final me = access.me!;
    final (label, color, icon) = !tr.clockedIn
        ? ('Not Clocked In', AppColors.muted, Icons.power_settings_new)
        : tr.onBreak
            ? ('On Break', AppColors.amber, Icons.free_breakfast)
            : ('Clocked In', AppColors.green, Icons.check_circle);
    final visits = tr.todaysVisits;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(trf('Hi, {}', [me.name.split(' ').first]), style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Chat with admin'.tr,
            icon: Badge(isLabelVisible: tr.unreadChat > 0, label: Text('${tr.unreadChat}'), child: const Icon(Icons.chat_bubble_outline)),
            onPressed: () => Navigator.of(context).push(slideRoute(const EmployeeChatScreen())),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: UserAvatar(photo: access.myAvatar, initials: me.initials, radius: 17),
          ),
        ],
      ),
      body: ListView(padding: Sp.screen, children: [
        if (access.myAvatar == null) ...[
          AddPhotoBanner(onTap: () => Navigator.of(context).push(slideRoute(const EditProfileScreen()))),
          const SizedBox(height: 12),
        ],
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((tr.clockedIn ? 'Clock Out' : 'Clock In').tr,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text((tr.clockedIn ? 'Toggle off to end your shift' : 'Toggle on to start your shift').tr,
                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ]),
                ),
                Switch(
                  value: tr.clockedIn,
                  onChanged: (_) async {
                    if (tr.clockedIn) {
                      if (!await confirm(context, 'End shift?', trf('You worked {} today.', [fmtDuration(tr.hoursToday)]), action: 'End shift')) return;
                      await tr.clockOut();
                      if (context.mounted) snack(context, 'Shift ended');
                    } else {
                      // Face check before the shift can start.
                      if (!await FaceVerifyScreen.run(context, FaceKind.clockIn)) return;
                      await tr.clockIn();
                      if (context.mounted) snack(context, 'Shift started');
                    }
                  },
                ),
              ]),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: StatusChip(label, color, icon: icon)),
              const Divider(height: 28),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Break'.tr, style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      (tr.clockedIn ? 'Toggle on when you take a break' : 'Clock in from Home to enable breaks').tr,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ]),
                ),
                Switch(
                  value: tr.onBreak,
                  onChanged: !tr.clockedIn
                      ? null
                      : (_) async {
                          if (tr.onBreak) {
                            // Face check when coming back from a break.
                            if (!await FaceVerifyScreen.run(context, FaceKind.breakEnd)) return;
                            await tr.endBreak();
                          } else {
                            await tr.startBreak();
                          }
                        },
                ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        _TargetCard(tr),
        const SizedBox(height: 16),
        if (tr.signalLost || tr.locationError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.m),
            child: GlassCard(
              borderColor: AppColors.amber,
              child: ListTile(
                leading: const Icon(Icons.location_off, color: AppColors.amber),
                title: Text((tr.locationError ?? 'Location signal lost').tr),
                subtitle: Text('Your admin cannot see your live position. Open Tracking to fix it.'.tr),
              ),
            ),
          ),
        TnCalendarCard(onTap: () => openStaffCalendar(context)).enter(),
        const SizedBox(height: Sp.m),
        Row(children: [
          Expanded(child: _Quick(Icons.beach_access, 'Leave', () => Navigator.of(context).push(slideRoute(const LeaveScreen())))),
          const SizedBox(width: Sp.m),
          Expanded(child: _Quick(Icons.campaign, 'Announcements', () => Navigator.of(context).push(slideRoute(const AnnouncementsScreen())))),
        ]),
        const SizedBox(height: Sp.l),
        StatGrid([
          StatTile(icon: Icons.timer_outlined, value: fmtDuration(tr.hoursToday), label: 'Hours today'.tr),
          StatTile(
            icon: Icons.task_alt,
            value: '${tr.jobsFinishedToday}',
            label: 'Jobs finished'.tr,
            color: AppColors.green,
            onTap: () => Navigator.of(context).push(slideRoute(const FinishedJobsScreen())),
          ),
          StatTile(
            icon: Icons.route_outlined,
            value: '${tr.distanceTodayKm.toStringAsFixed(1)} km',
            label: 'Distance today'.tr,
            color: AppColors.blue400,
            onTap: () => Navigator.of(context).push(slideRoute(RouteMapScreen.today(visits: tr.visits))),
          ),
        ]),
        const SectionTitle("Today's Rounds"),
        if (visits.isEmpty)
          const EmptyState(Icons.event_busy, 'No rounds scheduled today. A good day to catch up on reading.')
        else
          for (final (i, v) in visits.indexed) Padding(padding: const EdgeInsets.only(bottom: Sp.m), child: VisitCard(v).enter(i)),
      ]),
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

/// Today's progress towards the admin's daily visit target, plus the streak and a way into the leaderboard.
class _TargetCard extends StatelessWidget {
  final TrackingProvider tr;
  const _TargetCard(this.tr);

  @override
  Widget build(BuildContext context) {
    final done = tr.jobsFinishedToday;
    final target = tr.dailyTarget;
    final hit = done >= target;
    final streak = tr.streakDays;
    return GlassCard(
      borderColor: hit ? AppColors.green : null,
      onTap: () => Navigator.of(context).push(slideRoute(const LeaderboardScreen())),
      child: Padding(
        padding: const EdgeInsets.all(Sp.l),
        child: Row(children: [
          DonutProgress(
            value: target == 0 ? 0 : done / target,
            size: 78,
            stroke: 9,
            color: hit ? AppColors.green : null,
            center: Text('$done/$target', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(width: Sp.l),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((hit ? 'Target reached. Great work!' : "Today's target").tr, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 2),
              Text(hit ? 'Every extra visit counts on the leaderboard.'.tr : trf('{} more to go', [trCount(target - done, 'visit', 'visits')]),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (streak >= 1) StatusChip(trf('{}-day streak', [streak]), AppColors.amber, icon: Icons.local_fire_department),
                const StatusChip('Leaderboard', AppColors.accent, icon: Icons.emoji_events_outlined),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ]),
      ),
    );
  }
}
