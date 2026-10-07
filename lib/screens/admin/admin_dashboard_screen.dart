import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/access_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/radar_orbit.dart';
import '../../widgets/tn_calendar.dart';
import '../leaderboard_screen.dart';
import 'admin_activity_screen.dart';
import 'admin_employee_detail_screen.dart';

void _openEmployee(BuildContext context, Employee e) =>
    Navigator.of(context).push(slideRoute(AdminEmployeeDetailScreen(e)));

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final emps = access.approved;
    final onDuty = emps.where((e) => e.status == DutyStatus.onDuty).length;
    final onBreak = emps.where((e) => e.status == DutyStatus.onBreak).length;
    final off = emps.length - onDuty - onBreak;
    final lost = emps.where((e) => e.status == DutyStatus.onDuty && !e.isLive).length;
    final unread = emps.fold(0, (a, e) => a + e.unread);
    final updated = access.lastUpdated ?? DateTime.now();
    final share = emps.isEmpty ? 0.0 : (onDuty + onBreak) / emps.length;
    final t = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: access.refresh,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: Sp.screen, children: [
        Row(children: [
          Expanded(
            child: Text('Team on the field', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Text('Updated ${DateFormat('HH:mm').format(updated)}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        const Text('Tap a team member to see their visits, attendance and routes.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: Sp.m),
        RadarOrbit(employees: emps, photoOf: access.avatarOf, onTap: (e) => _openEmployee(context, e)).enter(),
        const SizedBox(height: Sp.l),
        const TnCalendarCard().enter(1),
        const SizedBox(height: Sp.l),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(Sp.l),
            child: Row(children: [
              DonutProgress(
                value: share,
                size: 110,
                stroke: 12,
                center: CountUp(share * 100, suffix: '%', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: Sp.l),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('On shift now', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  _Row(AppColors.green, 'On duty', onDuty),
                  _Row(AppColors.amber, 'On break', onBreak),
                  _Row(AppColors.muted, 'Off duty', off),
                  if (lost > 0) _Row(AppColors.red, 'Tracking lost', lost),
                ]),
              ),
            ]),
          ),
        ).enter(1),
        const SizedBox(height: Sp.m),
        StatGrid([
          StatTile(icon: Icons.groups_outlined, value: '${emps.length}', label: 'Employees'),
          StatTile(icon: Icons.mark_chat_unread_outlined, value: '$unread', label: 'Unread messages', color: AppColors.blue400),
        ]),
        const SizedBox(height: Sp.m),
        GlassCard(
          onTap: () => Navigator.of(context).push(slideRoute(const LeaderboardScreen())),
          child: const Padding(
            padding: EdgeInsets.all(Sp.l),
            child: Row(children: [
              Icon(Icons.emoji_events, color: Color(0xFFF5B301), size: 30),
              SizedBox(width: Sp.l),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Weekly leaderboard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('Who closed the most visits this week. Set the daily target here.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                ]),
              ),
              Icon(Icons.chevron_right, color: AppColors.muted),
            ]),
          ),
        ).enter(2),
        const SizedBox(height: Sp.m),
        RecentActivityCard(onTap: () => Navigator.of(context).push(slideRoute(const AdminActivityScreen()))).enter(3),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final Color color;
  final String label;
  final int n;
  const _Row(this.color, this.label, this.n);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          CountUp(n.toDouble(), style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
