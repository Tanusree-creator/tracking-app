import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/access_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'admin/admin_shell.dart';
import 'tech_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _admin = false;
  bool _register = false;
  bool _hide = true;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final access = context.read<AccessProvider>();
    try {
      if (_register) {
        await access.register(_name.text, _email.text, _password.text);
        if (!mounted) return;
        setState(() => _register = false);
        snack(context, 'Request sent. You can sign in once an admin approves your account.');
      } else {
        await access.login(_email.text, _password.text, admin: _admin);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => _admin ? const AdminShell() : const TechShell()));
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Icon(Icons.route_rounded, size: 44, color: AppColors.accent),
                  const SizedBox(height: 12),
                  Text(_register ? 'CREATE EMPLOYEE ACCOUNT' : 'SIGN IN TO ACCOUNT',
                      style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: .5)),
                  const SizedBox(height: 4),
                  Text(
                    _register
                        ? 'An admin must approve your request before you can sign in'
                        : 'Sign in to view your assigned tasks',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  if (!_register)
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Employee Login'), icon: Icon(Icons.engineering)),
                        ButtonSegment(value: true, label: Text('Admin Login'), icon: Icon(Icons.admin_panel_settings)),
                      ],
                      selected: {_admin},
                      onSelectionChanged: (s) => setState(() => _admin = s.first),
                    ),
                  const SizedBox(height: 16),
                  if (_register) ...[
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.mail_outline)),
                    validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _hide,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                    validator: (v) => (v ?? '').length < (_register ? 8 : 1)
                        ? (_register ? 'At least 8 characters' : 'Enter your password')
                        : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (!_register)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => snack(context, 'Ask your admin to reset your password.'),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.red.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.red))),
                      ]),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_register ? 'Request Access' : 'Sign In'),
                  ),
                  if (!_admin || _register)
                    TextButton(
                      onPressed: () => setState(() {
                        _register = !_register;
                        _error = null;
                      }),
                      child: Text(_register ? 'Already approved? Sign in' : 'New employee? Register'),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
