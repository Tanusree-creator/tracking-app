import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/access_provider.dart';
import '../../widgets/sticky_notification_banner.dart';
import '../login_screen.dart';
import 'admin_admins_screen.dart';
import 'admin_access_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_employees_screen.dart';
import 'admin_reports_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _i = 0;

  static const _pages = [AdminDashboardScreen(), AdminEmployeesScreen(), AdminReportsScreen(), AdminAccessScreen()];

  @override
  Widget build(BuildContext context) {
    final pending = context.watch<AccessProvider>().requests.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operations Control', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Manage admins',
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminAdminsScreen())),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AccessProvider>().logout();
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            },
          ),
        ],
      ),
      body: Column(children: [
        const StickyNotificationBanner(audience: AlertAudience.admin),
        Expanded(child: IndexedStack(index: _i, children: _pages)),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          const NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Employees'),
          const NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
          NavigationDestination(
            icon: Badge(isLabelVisible: pending > 0, label: Text('$pending'), child: const Icon(Icons.how_to_reg_outlined)),
            selectedIcon: const Icon(Icons.how_to_reg),
            label: 'Access',
          ),
        ],
      ),
    );
  }
}
