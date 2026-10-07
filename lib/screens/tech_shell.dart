import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/access_provider.dart';
import '../services/staff_provider.dart';
import '../services/tracking_provider.dart';
import '../widgets/anim.dart';
import '../widgets/glass.dart';
import '../widgets/sticky_notification_banner.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'tracking_screen.dart';
import 'profile_screen.dart';

class TechShell extends StatefulWidget {
  const TechShell({super.key});

  @override
  State<TechShell> createState() => _TechShellState();
}

class _TechShellState extends State<TechShell> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    final me = context.read<AccessProvider>().me!;
    context.read<TrackingProvider>().load(me.id);
    context.read<StaffProvider>().start(office: false); // leave requests + announcements
  }

  static const _pages = [HomeScreen(), TasksScreen(), TrackingScreen(), HistoryScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        body: Column(children: [
          const StickyNotificationBanner(audience: AlertAudience.employee),
          Expanded(child: AnimatedTabStack(index: _i, children: _pages)),
        ]),
        bottomNavigationBar: GlassBottomNav(
          index: _i,
          onChanged: (i) => setState(() => _i = i),
          items: const [
            GlassNavItem(Icons.home_outlined, Icons.home, 'Home'),
            GlassNavItem(Icons.checklist_outlined, Icons.checklist, 'Tasks'),
            GlassNavItem(Icons.my_location_outlined, Icons.my_location, 'Tracking'),
            GlassNavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'History'),
            GlassNavItem(Icons.person_outline, Icons.person, 'Profile'),
          ],
        ),
      );
}
