import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AdminAdminsScreen extends StatefulWidget {
  const AdminAdminsScreen({super.key});

  @override
  State<AdminAdminsScreen> createState() => _AdminAdminsScreenState();
}

class _AdminAdminsScreenState extends State<AdminAdminsScreen> {
  late Future<List<Map<String, dynamic>>> _future = Api.admins();

  void _reload() => setState(() => _future = Api.admins());

  Future<void> _delete(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove admin?'),
        content: Text('${a['email']} will no longer be able to sign in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red, minimumSize: const Size(100, 44)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.deleteAdmin(a['id'] as String);
      _reload();
    } catch (e) {
      if (mounted) snack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Admins')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final created = await showDialog<bool>(context: context, builder: (_) => const _CreateAdminDialog());
            if (created == true) _reload();
          },
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('New Admin'),
        ),
        body: FutureBuilder(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return ErrorState(snap.error.toString().replaceFirst('Exception: ', ''), _reload);
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final list = snap.data!;
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final a = list[i];
                final me = a['is_me'] == true;
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: AppColors.surfaceHigh, child: Icon(Icons.admin_panel_settings, color: AppColors.accent)),
                    title: Text(a['email'], style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Added ${DateFormat('d MMM y').format(DateTime.parse(a['created_at']).toLocal())}'),
                    trailing: me
                        ? const StatusChip('You', AppColors.accent)
                        : IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.red), onPressed: () => _delete(a)),
                  ),
                );
              },
            );
          },
        ),
      );
}

class _CreateAdminDialog extends StatefulWidget {
  const _CreateAdminDialog();

  @override
  State<_CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends State<_CreateAdminDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _created;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await Api.createAdmin(_email.text, _password.text);
      setState(() => _created = res);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _created;
    if (c != null) {
      final text = 'Email: ${c['email']}\nPassword: ${c['password']}';
      return AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.green, size: 40),
        title: const Text('Admin created'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Share these credentials now. The password is not shown again.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
            child: SelectableText(text),
          ),
        ]),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              snack(context, 'Copied');
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(minimumSize: const Size(80, 44)), child: const Text('Done')),
        ],
      );
    }
    return AlertDialog(
      title: const Text('New Admin'),
      content: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            decoration: const InputDecoration(labelText: 'Password', helperText: 'Leave blank to auto-generate'),
            validator: (v) => (v ?? '').isNotEmpty && v!.length < 8 ? 'At least 8 characters' : null,
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: AppColors.red))),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, style: FilledButton.styleFrom(minimumSize: const Size(120, 44)), child: const Text('Create')),
      ],
    );
  }
}
