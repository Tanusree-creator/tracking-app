import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import 'employee_providers.dart';

class CreateEmployeePage extends ConsumerStatefulWidget {
  const CreateEmployeePage({super.key});
  @override
  ConsumerState<CreateEmployeePage> createState() => _CreateEmployeePageState();
}

class _CreateEmployeePageState extends ConsumerState<CreateEmployeePage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _admin = false, _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  void _generate() {
    const chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = DateTime.now().microsecondsSinceEpoch;
    final buf = StringBuffer();
    var seed = r;
    for (var i = 0; i < 12; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      buf.write(chars[seed % chars.length]);
    }
    setState(() => _password.text = buf.toString());
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(employeeRepositoryProvider).create(
            name: _name.text,
            email: _email.text,
            password: _password.text,
            phone: _phone.text.isEmpty ? null : _phone.text,
            admin: _admin,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Account created'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Share these login details with the employee:'),
            const SizedBox(height: 12),
            SelectableText('Email: ${_email.text.trim()}\nPassword: ${_password.text}'),
          ]),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(
                  text: 'Email: ${_email.text.trim()}\nPassword: ${_password.text}')),
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(minimumSize: const Size(80, 40)),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) context.pop(true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New employee')),
      body: ListView(
        padding: Space.screen,
        children: [
          AppCard(
            padding: const EdgeInsets.all(Space.lg),
            child: Form(
              key: _form,
              child: Column(children: [
                AppTextField(
                  controller: _name,
                  label: 'Full name',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: Space.md),
                AppTextField(
                  controller: _email,
                  label: 'Login email',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: Space.md),
                AppTextField(
                  controller: _phone,
                  label: 'Phone (optional)',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: Space.md),
                AppTextField(
                  controller: _password,
                  label: 'Password (min 8 characters)',
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    tooltip: 'Generate',
                    icon: const Icon(Icons.auto_fix_high),
                    onPressed: _generate,
                  ),
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'At least 8 characters' : null,
                ),
                const SizedBox(height: Space.xs),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Make this user an admin'),
                  value: _admin,
                  onChanged: (v) => setState(() => _admin = v),
                ),
                AnimatedSize(
                  duration: Motion.fast,
                  curve: Motion.curve,
                  alignment: Alignment.topCenter,
                  child: _error == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: Text(_error!,
                              style: t.textTheme.bodySmall
                                  ?.copyWith(color: t.colorScheme.error)),
                        ),
                ),
                const SizedBox(height: Space.xs),
                AppButton(
                    label: 'Create account', loading: _busy, onPressed: _submit),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
