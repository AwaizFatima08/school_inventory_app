import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../common/ui_helpers.dart';

/// Email + password sign-in and registration for incharge / supervisor.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final repo = ref.read(accountRepositoryProvider);
    await runAction(
      context,
      () => _register
          ? repo.register(
              name: _name.text,
              email: _email.text,
              password: _password.text,
            )
          : repo.signIn(_email.text, _password.text),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _forgot() async {
    if (_email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type your email first.')),
      );
      return;
    }
    await runAction(
      context,
      () => ref.read(accountRepositoryProvider).sendPasswordReset(_email.text),
      success: 'Password reset email sent.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AppMark(),
                    const SizedBox(height: 12),
                    Text('School Inventory',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    const Text('Janitorial stock: demand, approval and issue',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    if (_register) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Your full name'),
                        validator: (v) =>
                            (v ?? '').trim().length < 2 ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                          (v ?? '').contains('@') ? null : 'Enter a valid email',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) => (v ?? '').length < 6
                          ? 'At least 6 characters'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_register ? 'Create account' : 'Sign in'),
                      ),
                    ),
                    if (!_register)
                      TextButton(
                        onPressed: _busy ? null : _forgot,
                        child: const Text('Forgot password?'),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _register = !_register),
                      child: Text(_register
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app icon (approved homidev cut-out) on the brand green.
class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 112,
        height: 112,
        decoration: const BoxDecoration(
          color: Color(0xFF2E7D32),
          shape: BoxShape.circle,
        ),
        child: Image.asset(
          'assets/icons/20261022-0239-school-inventory-app-icon-02_cutout.png',
          semanticLabel: 'School Inventory',
          cacheWidth: 336,
        ),
      ),
    );
  }
}
