import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:archespace_mobile/src/features/auth/data/auth_service.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/features/vault/data/vault_service.dart';
import 'package:archespace_mobile/src/features/vault/domain/vault_pin.dart';

/// First-run vault creation for a freshly registered account (no vault yet).
/// Creates a PIN-wrapped vault, shows the one-time recovery code, then unlocks
/// the in-memory session so the app can proceed.
class VaultSetupScreen extends StatefulWidget {
  const VaultSetupScreen({super.key});

  @override
  State<VaultSetupScreen> createState() => _VaultSetupScreenState();
}

class _VaultSetupScreenState extends State<VaultSetupScreen> {
  final AuthService _auth = AuthService();
  final VaultService _vault = VaultService();
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _loading = false;
  String? _error;

  // Set once setup succeeds; the recovery code is shown until acknowledged.
  Uint8List? _masterKey;
  String? _recoveryCode;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;

    final pinError = validateVaultPin(_pin.text);
    if (pinError != null) {
      setState(() => _error = pinError);
      return;
    }
    if (_pin.text != _confirm.text) {
      setState(() => _error = 'PINs do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _vault.setupVault(userId, _pin.text);
      setState(() {
        _masterKey = result.masterKey;
        _recoveryCode = result.recoveryCode;
      });
    } on VaultException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not create your vault. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _continue() {
    final key = _masterKey;
    if (key == null) return;
    // Unlocking rebuilds the root gate into the spaces list.
    VaultSession.instance.unlock(key);
  }

  @override
  Widget build(BuildContext context) {
    final recoveryCode = _recoveryCode;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create vault PIN'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _auth.signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: recoveryCode != null
                  ? _RecoveryCodeStep(code: recoveryCode, onContinue: _continue)
                  : _buildPinForm(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinForm(BuildContext context) {
    final warning = validateVaultPin(_pin.text) == null
        ? getWeakPinWarning(_pin.text)
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.shield_outlined, size: 48),
        const SizedBox(height: 16),
        Text('Create your vault PIN',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Choose a PIN or passphrase, at least $vaultPinMinLength characters. '
          'It encrypts your data and is separate from your login password. A '
          'one-time recovery code is shown next.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _pin,
          obscureText: true,
          enabled: !_loading,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            labelText: 'New vault PIN',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: true,
          enabled: !_loading,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _create(),
          decoration: const InputDecoration(
            labelText: 'Confirm vault PIN',
            border: OutlineInputBorder(),
          ),
        ),
        if (warning != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  size: 18, color: Theme.of(context).colorScheme.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(warning,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary)),
              ),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _create,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create PIN'),
          ),
        ),
      ],
    );
  }
}

class _RecoveryCodeStep extends StatelessWidget {
  const _RecoveryCodeStep({required this.code, required this.onContinue});

  final String code;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.vpn_key_outlined, size: 48),
        const SizedBox(height: 16),
        Text('Save your recovery code',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'This code is shown once. Use it to reset your PIN if you forget it. '
          'Store it somewhere safe.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 22,
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
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onContinue,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('I saved this code'),
          ),
        ),
      ],
    );
  }
}
