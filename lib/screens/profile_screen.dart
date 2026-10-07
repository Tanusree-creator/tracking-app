import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/access_provider.dart';
import '../services/api.dart';
import '../services/app_notifications_provider.dart';
import '../services/theme_controller.dart';
import '../services/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import '../widgets/glass.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final me = access.me!;
    final notif = context.watch<AppNotificationsProvider>();
    final theme = context.watch<ThemeController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: Sp.screen, children: [
        GlassCard(
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(children: [
              UserAvatar(photo: access.myAvatar, initials: me.initials, radius: 50, ring: AppColors.accent),
              const SizedBox(height: 14),
              Text(me.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              StatusChip(me.title, AppColors.accent),
              const SizedBox(height: 14),
              _InfoLine(Icons.mail_outline, me.email),
              if (me.phone != null) _InfoLine(Icons.phone_outlined, me.phone!),
              _InfoLine(Icons.place_outlined, me.district),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit profile'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44), shape: const StadiumBorder()),
              ),
            ]),
          ),
        ),
        if (access.myAvatar == null) ...[
          const SizedBox(height: 12),
          AddPhotoBanner(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
        ],
        const SizedBox(height: 12),
        GlassCard(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Messages'),
              subtitle: const Text('Credentials and notes from your admin'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Push Notifications'),
              value: notif.pushEnabled,
              onChanged: notif.setPush,
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Appearance'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: Sp.s),
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_suggest), label: Text('Auto')),
                  ],
                  selected: {theme.mode},
                  onSelectionChanged: (s) => theme.set(s.first),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Account Settings'),
              subtitle: const Text('To change your password, ask your admin'),
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
          onPressed: () async {
            if (context.read<TrackingProvider>().clockedIn) {
              snack(context, 'Clock out from Home before logging out, so your shift and tracking are closed properly.');
              return;
            }
            if (!await confirm(context, 'Log out?', 'You will need to sign in and verify your face again.', action: 'Log out', danger: true)) return;
            if (!context.mounted) return;
            context.read<TrackingProvider>().reset();
            await context.read<AccessProvider>().logout();
            if (!context.mounted) return;
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

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted))),
        ]),
      );
}

/// Highlighted prompt shown while the employee has no profile photo.
class AddPhotoBanner extends StatelessWidget {
  final VoidCallback onTap;
  const AddPhotoBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onTap,
        borderColor: AppColors.accent,
        tint: AppColors.accent.withValues(alpha: .14),
        child: const Padding(
          padding: EdgeInsets.all(Sp.l),
          child: Row(children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.accent, size: 28),
            SizedBox(width: Sp.m),
            Expanded(child: Text('Add your profile photo so your team and admin can recognise you.', style: TextStyle(fontWeight: FontWeight.w600))),
            Icon(Icons.chevron_right, color: AppColors.muted),
          ]),
        ),
      );
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
                  child: GlassCard(
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
