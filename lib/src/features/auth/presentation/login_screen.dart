import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:archespace_mobile/src/features/auth/data/auth_service.dart';
import 'package:archespace_mobile/src/features/auth/domain/email.dart';
import 'package:archespace_mobile/src/features/auth/domain/password_policy.dart';
import 'package:archespace_mobile/src/shared/config/app_config.dart';

enum _Mode { signIn, signUp }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  _Mode _mode = _Mode.signIn;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  bool get _isSignUp => _mode == _Mode.signUp;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _switchMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _info = null;
    });
  }

  Future<void> _submit() async {
    if (_loading) return;
    final emailError = validateEmail(_email.text.trim());
    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    if (_isSignUp) {
      await _createAccount();
    } else {
      await _signIn();
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await _auth.signIn(email: _email.text.trim(), password: _password.text);
      // On success the auth stream rebuilds the root gate -> unlock screen.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not sign in. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAccount() async {
    final pwError = validatePassword(_password.text);
    if (pwError != null) {
      setState(() => _error = pwError);
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final response = await _auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (response.session != null) {
        // Signed in immediately; the root gate takes over to set up the vault.
        return;
      }
      // Email confirmation required before the account can sign in.
      setState(() {
        _mode = _Mode.signIn;
        _password.clear();
        _confirm.clear();
        _info = 'Account created. Check your email to confirm your address, '
            'then sign in.';
      });
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not create your account. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Arche Space',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppConfig.allowSignup
                        ? 'Your private space - sign in or create an account'
                        : 'Sign in to your account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (AppConfig.allowSignup) ...[
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<_Mode>(
                        segments: const [
                          ButtonSegment(
                              value: _Mode.signIn, label: Text('Sign in')),
                          ButtonSegment(
                              value: _Mode.signUp, label: Text('Create account')),
                        ],
                        selected: {_mode},
                        showSelectedIcon: false,
                        onSelectionChanged: _loading
                            ? null
                            : (selection) => _switchMode(selection.first),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    enabled: !_loading,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    enabled: !_loading,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_isSignUp) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirm,
                      obscureText: _obscure,
                      enabled: !_loading,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _info!,
                      style: TextStyle(color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? 'Create account' : 'Sign in'),
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
