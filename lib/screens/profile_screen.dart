import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/access_provider.dart';
import '../services/api.dart';
import '../services/app_notifications_provider.dart';
import '../services/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AccessProvider>().me!;
    final notif = context.watch<AppNotificationsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              CircleAvatar(radius: 30, backgroundColor: AppColors.accent, child: Text(me.initials, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(me.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text(me.email, style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 8),
                  StatusChip(me.title, AppColors.accent),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Messages'),
              subtitle: const Text('Credentials and notes from your admin'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Full Profile'),
              subtitle: Text('${me.title} · ${me.district}'),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Push Notifications'),
              value: notif.pushEnabled,
              onChanged: notif.setPush,
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Account Settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => snack(context, 'To change your password, ask your admin.'),
            ),
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('Support Center'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => snack(context, 'Contact meritpublication@gmail.com for support.'),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            context.read<TrackingProvider>().reset();
            context.read<AccessProvider>().logout();
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
          },
          icon: const Icon(Icons.logout, color: AppColors.red),
          label: const Text('Log Out', style: TextStyle(color: AppColors.red)),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), side: const BorderSide(color: AppColors.red)),
        ),
      ]),
    );
  }
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Future<List<Map<String, dynamic>>> _future = Api.messages();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Messages'), actions: [
          IconButton(onPressed: () => setState(() => _future = Api.messages()), icon: const Icon(Icons.refresh)),
        ]),
        body: FutureBuilder(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return ErrorState(snap.error.toString().replaceFirst('Exception: ', ''),
                  () => setState(() => _future = Api.messages()));
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final msgs = snap.data!;
            if (msgs.isEmpty) return const EmptyState(Icons.mail_outline, 'No messages');
            return ListView(padding: const EdgeInsets.all(16), children: [
              for (final m in msgs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m['title'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 8),
                        SelectableText(m['body']),
                      ]),
                    ),
                  ),
                ),
            ]);
          },
        ),
      );
}
