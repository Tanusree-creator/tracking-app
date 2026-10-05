import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true, _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await ref
        .read(authProvider.notifier)
        .signIn(_email.text, _password.text);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: Space.screen,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(Space.sm),
                    decoration: BoxDecoration(
                      color: t.colorScheme.primary,
                      borderRadius: Radii.medium,
                    ),
                    child: const Icon(Icons.route_rounded,
                        size: 28, color: Colors.white),
                  ),
                  const SizedBox(height: Space.xl),
                  Text('Welcome back', style: t.textTheme.headlineMedium),
                  const SizedBox(height: Space.xs),
                  Text('Sign in with the account your admin created.',
                      style: t.textTheme.bodySmall),
                  const SizedBox(height: Space.xxl),
                  AppCard(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Form(
                      key: _form,
                      child: Column(children: [
                        AppTextField(
                          controller: _email,
                          label: 'Email',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Enter a valid email'
                              : null,
                        ),
                        const SizedBox(height: Space.md),
                        AppTextField(
                          controller: _password,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscure: _hide,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                          suffix: IconButton(
                            icon: Icon(_hide
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Enter your password'
                              : null,
                        ),
                        AnimatedSize(
                          duration: Motion.fast,
                          curve: Motion.curve,
                          alignment: Alignment.topCenter,
                          child: _error == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding:
                                      const EdgeInsets.only(top: Space.sm),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(_error!,
                                        style: t.textTheme.bodySmall?.copyWith(
                                            color: t.colorScheme.error)),
                                  ),
                                ),
                        ),
                        const SizedBox(height: Space.xl),
                        AppButton(
                            label: 'Sign in',
                            loading: _busy,
                            onPressed: _submit),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
