import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../l10n/l10n.dart';

class AdminAdminsScreen extends StatefulWidget {
  const AdminAdminsScreen({super.key});

  @override
  State<AdminAdminsScreen> createState() => _AdminAdminsScreenState();
}

class _AdminAdminsScreenState extends State<AdminAdminsScreen> {
  List<Map<String, dynamic>>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await Api.admins();
      if (mounted) {
        setState(() {
          _list = l;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '${e.toString().replaceFirst('Exception: ', '')}\n\nIf this says a function does not exist, run supabase/002_admin_management.sql in the Supabase SQL Editor.');
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    if (!await confirm(context, 'Remove admin?', trf('{} will no longer be able to sign in.', [a['email']]), action: 'Remove', danger: true)) return;
    try {
      await Api.deleteAdmin(a['id'] as String);
      _load();
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''), type: ToastType.error);
    }
  }

  Future<void> _new() async {
    final created = await Navigator.of(context).push<bool>(slideRoute(const NewAdminScreen()));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Scaffold(
      appBar: AppBar(title: Text('Admins'.tr, style: TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text('New admin'.tr),
      ),
      body: _error != null
          ? ErrorState(_error!, _load)
          : list == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final a = list[i];
                      final me = a['is_me'] == true;
                      return GlassCard(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: const CircleAvatar(backgroundColor: AppColors.surfaceHigh, child: Icon(Icons.admin_panel_settings, color: AppColors.accent)),
                          title: Text(a['email'] as String, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                          subtitle: Text(trf('Added {}', [DateFormat('d MMM y').format(DateTime.parse(a['created_at'] as String).toLocal())])),
                          trailing: me
                              ? const StatusChip('You', AppColors.accent)
                              : IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.red), onPressed: () => _delete(a)),
                        ),
                      ).enter(i);
                    },
                  ),
                ),
    );
  }
}

/// Full-screen "new admin" form; shows the credentials once created.
class NewAdminScreen extends StatefulWidget {
  const NewAdminScreen({super.key});

  @override
  State<NewAdminScreen> createState() => _NewAdminScreenState();
}

class _NewAdminScreenState extends State<NewAdminScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;
  Map<String, dynamic>? _created;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await Api.createAdmin(_email.text, _password.text);
      if (mounted) setState(() => _created = res);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _created;
    return Scaffold(
      appBar: AppBar(title: Text((c == null ? 'New admin' : 'Admin created').tr)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (c != null) ...[
            const SizedBox(height: 12),
            const Icon(Icons.check_circle, color: AppColors.green, size: 64),
            const SizedBox(height: 16),
            Text('Share these credentials now. The password is not shown again.'.tr, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: SelectableText('Email: ${c['email']}\nPassword: ${c['password']}', style: const TextStyle(fontSize: 16, height: 1.6)),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: 'Email: ${c['email']}\nPassword: ${c['password']}'));
                snack(context, 'Copied');
              },
              icon: const Icon(Icons.copy, size: 18),
              label: Text('Copy'.tr),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('Done'.tr)),
          ] else
            Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('The new admin can sign in with these details and manage employees, tasks and reports.'.tr, style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 20),
                GlowTextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: 'Email address'.tr, prefixIcon: Icon(Icons.mail_outline)),
                  validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 14),
                GlowTextField(
                  controller: _password,
                  obscureText: _hide,
                  decoration: InputDecoration(
                    labelText: 'Password'.tr,
                    helperText: 'Leave blank to auto-generate a strong one'.tr,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _hide = !_hide)),
                  ),
                  validator: (v) => (v ?? '').isNotEmpty && v!.length < 8 ? 'At least 8 characters' : null,
                  onFieldSubmitted: (_) => _save(),
                ),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.red.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.red))),
                    ]),
                  ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Create admin'.tr),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
