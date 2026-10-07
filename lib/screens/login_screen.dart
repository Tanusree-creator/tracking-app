import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/access_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/language_picker.dart';
import 'home_router.dart';
import 'face_verify_screen.dart';
import '../widgets/glass.dart';
import '../l10n/l10n.dart';

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
        snack(
          context,
          'Request sent. You can sign in once an admin approves your account.',
        );
      } else {
        await access.login(_email.text, _password.text, admin: _admin);
        if (!mounted) return;
        if (!_admin) {
          // Employees prove it's them before entering the app.
          final ok = await FaceVerifyScreen.run(context, FaceKind.signIn);
          if (!mounted) return;
          if (!ok) {
            await access.logout();
            setState(
              () => _error = 'Face verification is required to sign in.',
            );
            return;
          }
        }
        Navigator.of(context).pushReplacement(fadeRoute(homeFor(access)));
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
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: BrandLogo(
                            size: 230,
                            white:
                                Theme.of(context).brightness == Brightness.dark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Words that reach every reader'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            letterSpacing: .4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          (_register
                              ? 'Join the Merit team'
                              : 'Welcome to Merit Publication').tr,
                          style: t.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (_register
                              ? 'An admin must approve your request before you can sign in'
                              : 'Sign in to pick up today’s rounds and deliveries').tr,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 24),
                        if (!_register)
                          SegmentedButton<bool>(
                            segments: [
                              ButtonSegment(
                                value: false,
                                label: Text('Employee'.tr),
                                icon: Icon(Icons.engineering),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Admin'.tr),
                                icon: Icon(Icons.admin_panel_settings),
                              ),
                            ],
                            selected: {_admin},
                            onSelectionChanged: (s) =>
                                setState(() => _admin = s.first),
                          ),
                        const SizedBox(height: 16),
                        if (_register) ...[
                          GlowTextField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: InputDecoration(
                              labelText: 'Full name'.tr,
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'Enter your name'
                                : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        GlowTextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            labelText: 'Email address'.tr,
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (v) =>
                              RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch((v ?? '').trim())
                              ? null
                              : 'Enter a valid email',
                        ),
                        const SizedBox(height: 12),
                        GlowTextField(
                          controller: _password,
                          obscureText: _hide,
                          textInputAction: TextInputAction.done,
                          autofillHints: [
                            _register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Password'.tr,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _hide ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () => setState(() => _hide = !_hide),
                            ),
                          ),
                          validator: (v) =>
                              (v ?? '').length < (_register ? 8 : 1)
                              ? (_register
                                    ? 'At least 8 characters'
                                    : 'Enter your password')
                              : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (!_register)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => snack(
                                context,
                                'Ask your admin to reset your password.',
                              ),
                              child: Text('Forgot password?'.tr),
                            ),
                          ),
                        if (_error != null)
                          Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!.tr,
                                    style: const TextStyle(
                                      color: AppColors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text((_register ? 'Request Access' : 'Sign In').tr),
                        ),
                        if (!_admin || _register)
                          TextButton(
                            onPressed: () => setState(() {
                              _register = !_register;
                              _error = null;
                            }),
                            child: Text(
                              (_register
                                  ? 'Already approved? Sign in'
                                  : 'New employee? Register').tr,
                            ),
                          ),
                      ],
                    ),
                  ).enter(),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            right: 8,
            child: const LanguageButton(),
          ),
        ],
      ),
    );
  }
}
