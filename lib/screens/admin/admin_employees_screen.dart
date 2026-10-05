import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/access_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'admin_dashboard_screen.dart' show dutyStyle;
import 'admin_employee_detail_screen.dart';

class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final list = access.approved
        .where((e) => e.name.toLowerCase().contains(_q) || e.email.toLowerCase().contains(_q))
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (_) => const _CreateUserDialog()),
        icon: const Icon(Icons.person_add),
        label: const Text('New Employee'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Look Up employee', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionTitle('Employee Registry · Approved Employees (${list.length})'),
        ),
        if (access.error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(access.error!, style: const TextStyle(color: AppColors.red))),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(Icons.search_off, 'No employees found')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = list[i];
                    final (label, color) = dutyStyle(e.status);
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: AppColors.surfaceHigh, child: Text(e.initials)),
                        title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${e.title} · ${e.district}'),
                        trailing: StatusChip(label, color),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminEmployeeDetailScreen(e))),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
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
      final res = await context.read<AccessProvider>().createUser(_name.text, _email.text, _password.text);
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
        title: const Text('Employee created'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('These credentials were sent to them as an in-app message.', textAlign: TextAlign.center),
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
          FilledButton(onPressed: () => Navigator.pop(context), style: FilledButton.styleFrom(minimumSize: const Size(80, 44)), child: const Text('Done')),
        ],
      );
    }
    return AlertDialog(
      title: const Text('New Employee'),
      content: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email'),
          const SizedBox(height: 12),
          TextFormField(controller: _password, decoration: const InputDecoration(labelText: 'Password', helperText: 'Leave blank to auto-generate'), validator: (v) => (v ?? '').isNotEmpty && v!.length < 8 ? 'At least 8 characters' : null),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: AppColors.red))),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, style: FilledButton.styleFrom(minimumSize: const Size(120, 44)), child: const Text('Create & Send')),
      ],
    );
  }
}
