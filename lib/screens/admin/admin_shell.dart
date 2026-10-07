import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/access_provider.dart';
import '../../services/app_notifications_provider.dart';
import '../../widgets/anim.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/sticky_notification_banner.dart';
import '../../widgets/language_picker.dart';
import '../../l10n/l10n.dart';
import '../chat_screens.dart';
import '../login_screen.dart';
import 'admin_access_screen.dart';
import 'admin_admins_screen.dart';
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
  Timer? _live;

  static const _pages = [AdminDashboardScreen(), AdminEmployeesScreen(), AdminReportsScreen(), AdminChatListScreen(), AdminAccessScreen()];
  static const _titles = ['Merit Desk', 'Our Team', 'Reports', 'Chat', 'Access'];

  @override
  void initState() {
    super.initState();
    // Pop-ups for shifts, tasks created/closed, messages. Plus a live refresh of positions.
    context.read<AppNotificationsProvider>().startAdminPolling();
    _live = Timer.periodic(const Duration(seconds: 15), (_) => context.read<AccessProvider>().refresh(silent: true));
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    if (!await confirm(context, 'Log out?', 'You will need to sign in again.', action: 'Log out', danger: true)) return;
    if (!mounted) return;
    final notifications = context.read<AppNotificationsProvider>();
    final access = context.read<AccessProvider>();
    final nav = Navigator.of(context);
    notifications.stopAdminPolling();
    await access.logout();
    nav.pushAndRemoveUntil(fadeRoute(const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final pending = access.requests.length;
    final unread = access.approved.fold(0, (a, e) => a + e.unread);
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        flexibleSpace: const GlassBarSpace(),
        titleSpacing: 16,
        title: Row(children: [
          BrandLogo(size: 56, white: Theme.of(context).brightness == Brightness.dark),
          const SizedBox(width: 10),
          Text(_titles[_i].tr, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          const LanguageButton(),
          IconButton(
            tooltip: 'Manage admins'.tr,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () => Navigator.of(context).push(slideRoute(const AdminAdminsScreen())),
          ),
          IconButton(tooltip: 'Log out'.tr, icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Column(children: [
        const StickyNotificationBanner(audience: AlertAudience.admin),
        Expanded(child: AnimatedTabStack(index: _i, children: _pages)),
      ]),
      bottomNavigationBar: GlassBottomNav(
        index: _i,
        onChanged: (i) => setState(() => _i = i),
        items: [
          const GlassNavItem(Icons.radar_outlined, Icons.radar, 'Live'),
          const GlassNavItem(Icons.groups_outlined, Icons.groups, 'Team'),
          const GlassNavItem(Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
          GlassNavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat', badge: unread),
          GlassNavItem(Icons.how_to_reg_outlined, Icons.how_to_reg, 'Access', badge: pending),
        ],
      ),
    );
  }
}
