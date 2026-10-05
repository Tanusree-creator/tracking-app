import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/access_provider.dart';
import '../services/tracking_provider.dart';
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
  }

  static const _pages = [HomeScreen(), TasksScreen(), TrackingScreen(), HistoryScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          const StickyNotificationBanner(audience: AlertAudience.employee),
          Expanded(child: IndexedStack(index: _i, children: _pages)),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (i) => setState(() => _i = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Tasks'),
            NavigationDestination(icon: Icon(Icons.my_location_outlined), selectedIcon: Icon(Icons.my_location), label: 'Tracking'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'History'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      );
}
