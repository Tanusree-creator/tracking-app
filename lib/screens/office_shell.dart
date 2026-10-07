import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/access_provider.dart';
import '../services/staff_provider.dart';
import '../services/tracking_provider.dart';
import '../widgets/anim.dart';
import '../widgets/glass.dart';
import '../widgets/sticky_notification_banner.dart';
import 'follow_ups_screen.dart';
import 'office_home_screen.dart';
import 'office_tasks_screen.dart';
import 'profile_screen.dart';
import 'staff_calendar.dart';

/// App for office staff: home, tasks, calls, calendar and profile. No clock-in, face checks or location tracking.
class OfficeShell extends StatefulWidget {
  const OfficeShell({super.key});

  @override
  State<OfficeShell> createState() => _OfficeShellState();
}

class _OfficeShellState extends State<OfficeShell> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    final me = context.read<AccessProvider>().me!;
    // The tracking provider is only used for the chat counter here; office staff are never clocked in or tracked.
    context.read<TrackingProvider>().load(me.id);
    context.read<StaffProvider>().start(office: true);
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StaffProvider>();
    return Scaffold(
      extendBody: true,
      body: Column(children: [
        const StickyNotificationBanner(audience: AlertAudience.employee),
        Expanded(
          child: AnimatedTabStack(index: _i, children: [
            OfficeHomeScreen(goToTab: (i) => setState(() => _i = i)),
            const OfficeTasksScreen(),
            const FollowUpsScreen(),
            const StaffCalendarTab(),
            const ProfileScreen(),
          ]),
        ),
      ]),
      bottomNavigationBar: GlassBottomNav(
        index: _i,
        onChanged: (i) => setState(() => _i = i),
        items: [
          GlassNavItem(Icons.home_outlined, Icons.home, 'Home'.tr),
          GlassNavItem(Icons.checklist_outlined, Icons.checklist, 'Tasks'.tr, badge: sp.pendingTasks),
          GlassNavItem(Icons.phone_in_talk_outlined, Icons.phone_in_talk, 'Calls'.tr, badge: sp.dueCalls),
          GlassNavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Calendar'.tr),
          GlassNavItem(Icons.person_outline, Icons.person, 'Profile'.tr),
        ],
      ),
    );
  }
}
