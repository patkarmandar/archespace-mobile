import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:archespace_mobile/src/features/auth/data/auth_service.dart';
import 'package:archespace_mobile/src/features/auth/domain/email.dart';
import 'package:archespace_mobile/src/features/auth/domain/password_policy.dart';
import 'package:archespace_mobile/src/features/vault/data/vault_service.dart';
import 'package:archespace_mobile/src/features/vault/domain/vault_pin.dart';

/// Returns the signed-in user id, or throws if the session vanished.
String _requireUserId(AuthService auth) {
  final id = auth.currentUser?.id;
  if (id == null) throw StateError('Not signed in');
  return id;
}

String _authMessage(Object error) {
  if (error is AuthException) return error.message;
  if (error is VaultException) return error.message;
  return 'Something went wrong. Check your connection and try again.';
}

// ---------------------------------------------------------------------------
// Change email (two steps: password check + code sent to the current address).
// ---------------------------------------------------------------------------

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _newEmail = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _code = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _codeStep = false;

  @override
  void dispose() {
    _newEmail.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final messenger = ScaffoldMessenger.of(context);
    final nextEmail = _newEmail.text.trim().toLowerCase();
    final current = _auth.currentUser?.email?.toLowerCase();
    final emailError = validateEmail(nextEmail);
    if (emailError != null) {
      messenger.showSnackBar(SnackBar(content: Text(emailError)));
      return;
    }
    if (nextEmail == current) {
      messenger.showSnackBar(const SnackBar(
          content: Text('New email must be different from your current one.')));
      return;
    }
    if (_password.text.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Enter your login password to continue.')));
      return;
    }

    setState(() => _loading = true);
    try {
      // Verify the password, then send a reauthentication code to the old email.
      await _auth.signIn(email: current!, password: _password.text);
      await _auth.reauthenticate();
      if (!mounted) return;
      setState(() => _codeStep = true);
      messenger.showSnackBar(const SnackBar(
          content: Text('We sent a 6-digit code to your current email.')));
    } on AuthException catch (e) {
      final invalid = e.message.toLowerCase().contains('invalid');
      messenger.showSnackBar(SnackBar(
          content: Text(invalid ? 'Login password is incorrect.' : e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_authMessage(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmChange() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final nextEmail = _newEmail.text.trim().toLowerCase();
    if (_code.text.trim().isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter the 6-digit code.')));
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.updateEmail(nextEmail, _code.text.trim());
      await _auth.signOut();
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Confirmation link sent to your new email. Open it, then sign in again.'),
      ));
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text(_authMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = _auth.currentUser?.email ?? 'Unknown';
    return Scaffold(
      appBar: AppBar(title: const Text('Change email')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Current email: $currentEmail',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              "We'll email a 6-digit code to your current address to confirm "
              "it's you. After you enter it, a confirmation link is sent to your "
              'new address, and the change takes effect once you open it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            if (!_codeStep) ...[
              TextField(
                controller: _newEmail,
                keyboardType: TextInputType.emailAddress,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'New email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _ObscureField(
                controller: _password,
                label: 'Login password',
                obscure: _obscure,
                enabled: !_loading,
                onToggle: () => setState(() => _obscure = !_obscure),
              ),
              const SizedBox(height: 20),
              _SubmitButton(
                label: 'Send code',
                loading: _loading,
                onPressed: _sendCode,
              ),
            ] else ...[
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              _SubmitButton(
                label: 'Confirm email change',
                loading: _loading,
                onPressed: _confirmChange,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : _sendCode,
                child: const Text('Resend code'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Change login password.
// ---------------------------------------------------------------------------

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _resetLoading = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final email = _auth.currentUser?.email;

    if (_current.text.isEmpty || email == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter your current password.')));
      return;
    }
    if (_next.text.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter a new password.')));
      return;
    }
    final pwError = validatePassword(_next.text);
    if (pwError != null) {
      messenger.showSnackBar(
          SnackBar(content: Text(pwError.replaceFirst('Password', 'New password'))));
      return;
    }
    if (_confirm.text.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Confirm your new password.')));
      return;
    }
    if (_next.text != _confirm.text) {
      messenger.showSnackBar(
          const SnackBar(content: Text('New passwords do not match.')));
      return;
    }

    setState(() => _loading = true);
    try {
      // Verify the current password first, then update and force a re-login.
      await _auth.signIn(email: email, password: _current.text);
      await _auth.updatePassword(_next.text);
      await _auth.signOut();
      messenger.showSnackBar(const SnackBar(
        content: Text('Login password updated. Sign in again with your new password.'),
      ));
      navigator.popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (mounted) setState(() => _loading = false);
      final invalid = e.message.toLowerCase().contains('invalid');
      messenger.showSnackBar(SnackBar(
          content: Text(invalid ? 'Current password is incorrect.' : e.message)));
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text(_authMessage(e))));
    }
  }

  Future<void> _sendReset() async {
    final messenger = ScaffoldMessenger.of(context);
    final email = _auth.currentUser?.email;
    if (email == null) return;
    setState(() => _resetLoading = true);
    try {
      await _auth.requestPasswordReset(email);
      messenger.showSnackBar(const SnackBar(
          content: Text('Password reset link sent. Check your email.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_authMessage(e))));
    } finally {
      if (mounted) setState(() => _resetLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change login password')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Used to sign in. Separate from your vault PIN.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
            _ObscureField(
              controller: _current,
              label: 'Current password',
              obscure: _obscure,
              enabled: !_loading,
              onToggle: () => setState(() => _obscure = !_obscure),
            ),
            const SizedBox(height: 12),
            _ObscureField(
              controller: _next,
              label: 'New password',
              obscure: _obscure,
              enabled: !_loading,
              onToggle: () => setState(() => _obscure = !_obscure),
            ),
            const SizedBox(height: 12),
            _ObscureField(
              controller: _confirm,
              label: 'Confirm new password',
              obscure: _obscure,
              enabled: !_loading,
              onToggle: () => setState(() => _obscure = !_obscure),
            ),
            const SizedBox(height: 20),
            _SubmitButton(
              label: 'Change login password',
              loading: _loading,
              onPressed: _changePassword,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: (_loading || _resetLoading) ? null : _sendReset,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _resetLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Forgot current password? Send reset link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Change vault PIN with the current PIN.
// ---------------------------------------------------------------------------

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final AuthService _auth = AuthService();
  final VaultService _vault = VaultService();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_current.text.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter your current vault PIN.')));
      return;
    }
    if (_next.text.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter a new vault PIN.')));
      return;
    }
    final pinError = validateVaultPin(_next.text);
    if (pinError != null) {
      messenger.showSnackBar(SnackBar(content: Text(pinError)));
      return;
    }
    if (_confirm.text.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Confirm your new vault PIN.')));
      return;
    }
    if (_next.text != _confirm.text) {
      messenger.showSnackBar(
          const SnackBar(content: Text('New PINs do not match.')));
      return;
    }

    setState(() => _loading = true);
    try {
      await _vault.changePin(_requireUserId(_auth), _current.text, _next.text);
      messenger.showSnackBar(
          const SnackBar(content: Text('Vault PIN updated.')));
      navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text(_authMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final warning = validateVaultPin(_next.text) == null
        ? getWeakPinWarning(_next.text)
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Change vault PIN')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Unlocks encrypted data. PIN or passphrase, at least '
              '$vaultPinMinLength characters.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            _PinField(
              controller: _current,
              label: 'Current vault PIN',
              enabled: !_loading,
            ),
            const SizedBox(height: 12),
            _PinField(
              controller: _next,
              label: 'New vault PIN',
              enabled: !_loading,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _PinField(
              controller: _confirm,
              label: 'Confirm new vault PIN',
              enabled: !_loading,
            ),
            if (warning != null) ...[
              const SizedBox(height: 12),
              _WeakPinNote(message: warning),
            ],
            const SizedBox(height: 20),
            _SubmitButton(
              label: 'Change vault PIN',
              loading: _loading,
              onPressed: _changePin,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generate / replace the recovery code with the current PIN.
// ---------------------------------------------------------------------------

class SetupRecoveryScreen extends StatefulWidget {
  const SetupRecoveryScreen({super.key});

  @override
  State<SetupRecoveryScreen> createState() => _SetupRecoveryScreenState();
}

class _SetupRecoveryScreenState extends State<SetupRecoveryScreen> {
  final AuthService _auth = AuthService();
  final VaultService _vault = VaultService();
  final TextEditingController _pin = TextEditingController();

  bool _loading = false;
  String? _code;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final code = await _vault.createRecoveryCode(_requireUserId(_auth), _pin.text);
      setState(() => _code = code);
      _pin.clear();
      messenger.showSnackBar(
          const SnackBar(content: Text('Recovery code created. Save it now.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_authMessage(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinReady = _pin.text.length >= vaultPinMinLength;
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery code')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Use your current vault PIN to create or replace your one-time '
              'recovery code. It can reset your PIN if you forget it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            _PinField(
              controller: _pin,
              label: 'Current vault PIN',
              enabled: !_loading,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            _SubmitButton(
              label: 'Create recovery code',
              loading: _loading,
              onPressed: pinReady ? _create : null,
            ),
            if (_code != null) ...[
              const SizedBox(height: 20),
              _RecoveryCodeCard(code: _code!),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reset vault PIN with a recovery code.
// ---------------------------------------------------------------------------

class ResetPinScreen extends StatefulWidget {
  const ResetPinScreen({super.key});

  @override
  State<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends State<ResetPinScreen> {
  final AuthService _auth = AuthService();
  final VaultService _vault = VaultService();
  final TextEditingController _recoveryCode = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _loading = false;
  String? _newCode;

  @override
  void dispose() {
    _recoveryCode.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_recoveryCode.text.trim().isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter your recovery code.')));
      return;
    }
    if (_next.text.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter a new vault PIN.')));
      return;
    }
    final pinError = validateVaultPin(_next.text);
    if (pinError != null) {
      messenger.showSnackBar(SnackBar(content: Text(pinError)));
      return;
    }
    if (_confirm.text.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Confirm your new vault PIN.')));
      return;
    }
    if (_next.text != _confirm.text) {
      messenger.showSnackBar(
          const SnackBar(content: Text('New PINs do not match.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final code = await _vault.changePinWithRecoveryCode(
        _requireUserId(_auth),
        _recoveryCode.text,
        _next.text,
      );
      setState(() => _newCode = code);
      _recoveryCode.clear();
      _next.clear();
      _confirm.clear();
      messenger.showSnackBar(const SnackBar(
          content: Text('Vault PIN updated. Save your new recovery code.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_authMessage(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final warning = validateVaultPin(_next.text) == null
        ? getWeakPinWarning(_next.text)
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset PIN with recovery code')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Use your recovery code to set a new vault PIN.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
            TextField(
              controller: _recoveryCode,
              enabled: !_loading,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Recovery code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _PinField(
              controller: _next,
              label: 'New vault PIN',
              enabled: !_loading,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _PinField(
              controller: _confirm,
              label: 'Confirm new vault PIN',
              enabled: !_loading,
            ),
            if (warning != null) ...[
              const SizedBox(height: 12),
              _WeakPinNote(message: warning),
            ],
            const SizedBox(height: 20),
            _SubmitButton(
              label: 'Reset PIN with recovery code',
              loading: _loading,
              onPressed: _reset,
            ),
            if (_newCode != null) ...[
              const SizedBox(height: 20),
              _RecoveryCodeCard(code: _newCode!),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delete account permanently.
// ---------------------------------------------------------------------------

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final AuthService _auth = AuthService();
  final VaultService _vault = VaultService();
  final TextEditingController _confirmText = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _pin = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _confirmText.dispose();
    _password.dispose();
    _pin.dispose();
    super.dispose();
  }

  String get _phrase => 'DELETE ${_auth.currentUser?.email ?? ''}';

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final email = _auth.currentUser?.email;

    if (_confirmText.text != _phrase) {
      messenger.showSnackBar(
          SnackBar(content: Text('Type "$_phrase" to confirm.')));
      return;
    }
    if (_password.text.isEmpty || _pin.text.isEmpty || email == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Enter your login password and vault PIN.')));
      return;
    }

    setState(() => _loading = true);
    try {
      // Re-verify both credentials before the irreversible delete.
      await _auth.signIn(email: email, password: _password.text);
      await _vault.unlock(_requireUserId(_auth), _pin.text);
      await _auth.deleteAccount();
      messenger.showSnackBar(
          const SnackBar(content: Text('Your account has been deleted.')));
      navigator.popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (mounted) setState(() => _loading = false);
      final invalid = e.message.toLowerCase().contains('invalid');
      messenger.showSnackBar(SnackBar(
          content: Text(invalid ? 'Login password is incorrect.' : e.message)));
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text(_authMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: danger.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: danger),
                      const SizedBox(width: 8),
                      Text('This action is permanent',
                          style: TextStyle(
                              color: danger, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'All spaces and items are permanently deleted. Your encrypted '
                    'vault cannot be recovered afterward, even with your recovery code.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Type '),
                TextSpan(
                    text: _phrase,
                    style: TextStyle(
                        color: danger,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600)),
                const TextSpan(text: ' and re-enter your credentials.'),
              ]),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmText,
              enabled: !_loading,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Confirmation text',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _ObscureField(
              controller: _password,
              label: 'Login password',
              obscure: _obscure,
              enabled: !_loading,
              onToggle: () => setState(() => _obscure = !_obscure),
            ),
            const SizedBox(height: 12),
            _PinField(
              controller: _pin,
              label: 'Vault PIN',
              enabled: !_loading,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _delete,
              style: FilledButton.styleFrom(backgroundColor: danger),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Delete account permanently'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets.
// ---------------------------------------------------------------------------

class _ObscureField extends StatelessWidget {
  const _ObscureField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.enabled,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    required this.enabled,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      enabled: enabled,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _WeakPinNote extends StatelessWidget {
  const _WeakPinNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
        ),
      ],
    );
  }
}

class _RecoveryCodeCard extends StatelessWidget {
  const _RecoveryCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New one-time recovery code',
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    letterSpacing: 3,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Recovery code copied.')));
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Save this code now. It replaces any previous recovery code.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label),
      ),
    );
  }
}
