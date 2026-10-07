import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/access_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../l10n/l10n.dart';
import 'admin_employee_detail_screen.dart';
import 'open_employee.dart';
import 'admin_live_map_screen.dart';
import '../../widgets/glass.dart';

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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (_) => const _CreateUserDialog()),
        icon: const Icon(Icons.person_add),
        label: Text('New Employee'.tr),
      ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GlowTextField(
            decoration: InputDecoration(hintText: 'Look Up employee'.tr, prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GlassCard(
            onTap: () => Navigator.of(context).push(slideRoute(const AdminLiveMapScreen())),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: AppColors.surfaceHigh, child: Icon(Icons.map_outlined, color: AppColors.accent)),
              title: Text('Live field map'.tr, style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Where everyone is now, plus task locations'.tr),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionTitle(trf('Employee Registry · Approved Employees ({})', [list.length])),
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
                    final (label, color, icon) = dutyStyle(e.status);
                    return GlassCard(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: UserAvatar(photo: access.avatarOf(e.id), initials: e.initials, radius: 22),
                        title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(e.isOffice ? '${e.title} · ${'Office staff'.tr}' : '${e.title} · ${e.district}'),
                        trailing: e.isOffice ? StatusChip('Office'.tr, const Color(0xFF7C4DFF), icon: Icons.business_center_outlined) : StatusChip(label.tr, color, icon: icon),
                        onTap: () => openEmployee(context, e),
                        onLongPress: () => _changeType(context, e),
                      ),
                    ).enter(i);
                  },
                ),
        ),
      ]),
    );
  }
}

/// Long-press a person to move them between marketing (GPS tracked) and office staff.
Future<void> _changeType(BuildContext context, Employee e) async {
  final to = e.isOffice ? 'field' : 'office';
  final ok = await confirm(context, 'Change staff type?',
      trf(e.isOffice ? '{} will become marketing staff and be tracked with GPS.' : '{} will become office staff (no GPS tracking).', [e.name]),
      action: 'Change');
  if (!ok || !context.mounted) return;
  try {
    await context.read<AccessProvider>().setStaffType(e, to);
    if (context.mounted) toast(context, 'Staff type updated', type: ToastType.success);
  } catch (err) {
    if (context.mounted) toast(context, 'Could not save: ${err.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
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
  String _staffType = 'field';

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await context.read<AccessProvider>().createUser(_name.text, _email.text, _password.text, staffType: _staffType);
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
        title: Text('Employee created'.tr),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('These credentials were sent to them as an in-app message. You can also share them by WhatsApp, SMS or email.'.tr, textAlign: TextAlign.center),
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
            label: Text('Copy'.tr),
          ),
          TextButton.icon(
            onPressed: () => SharePlus.instance.share(ShareParams(
              subject: 'Your Merit Publication login',
              text: 'Hello ${_name.text.trim()},\n\nYour Merit Publication app login:\n$text\n\nPlease keep these safe.',
            )),
            icon: const Icon(Icons.share, size: 18),
            label: Text('Share'.tr),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), style: FilledButton.styleFrom(minimumSize: const Size(80, 44)), child: Text('Done'.tr)),
        ],
      );
    }
    return AlertDialog(
      title: Text('New Employee'.tr),
      content: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'field', icon: const Icon(Icons.directions_walk), label: Text('Marketing'.tr)),
              ButtonSegment(value: 'office', icon: const Icon(Icons.business_center_outlined), label: Text('Office'.tr)),
            ],
            selected: {_staffType},
            onSelectionChanged: (s) => setState(() => _staffType = s.first),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            child: Text((_staffType == 'office' ? 'Office staff get tasks, calls and leave. No GPS tracking.' : 'Marketing staff are tracked on the field with GPS.').tr, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ),
          GlowTextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Name'.tr), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          GlowTextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email'.tr), validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email'),
          const SizedBox(height: 12),
          GlowTextField(controller: _password, decoration: InputDecoration(labelText: 'Password'.tr, helperText: 'Leave blank to auto-generate'.tr), validator: (v) => (v ?? '').isNotEmpty && v!.length < 8 ? 'At least 8 characters' : null),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: AppColors.red))),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text('Cancel'.tr)),
        FilledButton(onPressed: _busy ? null : _save, style: FilledButton.styleFrom(minimumSize: const Size(120, 44)), child: Text('Create & Send'.tr)),
      ],
    );
  }
}
