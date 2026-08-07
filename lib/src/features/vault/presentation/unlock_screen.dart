import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/auth/data/auth_service.dart';
import 'package:archespace_mobile/src/features/vault/data/biometric_service.dart';
import 'package:archespace_mobile/src/features/vault/data/secure_key_store.dart';
import 'package:archespace_mobile/src/features/vault/data/vault_service.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/shared/widgets/confirm_dialog.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final AuthService _auth = AuthService();
  final VaultService _vault = VaultService();
  final SecureKeyStore _store = SecureKeyStore();
  final BiometricService _biometric = BiometricService();
  final TextEditingController _pin = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _initBiometric() async {
    final available = await _biometric.isAvailable();
    final enabled = available && await _store.hasKey();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
    });
    if (enabled) {
      _unlockWithBiometrics();
    }
  }

  Future<void> _unlockWithBiometrics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await _biometric.authenticate('Unlock your Arche vault');
      if (!ok) return;
      final masterKey = await _store.readMasterKey();
      if (masterKey == null) {
        // Stored key vanished (e.g. cleared) — fall back to PIN.
        setState(() => _biometricEnabled = false);
        return;
      }
      VaultSession.instance.unlock(masterKey);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlockWithPin() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;

    if (_pin.text.trim().isEmpty) {
      setState(() => _error = 'Enter your vault PIN.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final masterKey = await _vault.unlock(userId, _pin.text.trim());

      // Offer to enable biometric unlock for next time, before we navigate away.
      if (_biometricAvailable && !_biometricEnabled && mounted) {
        if (await _askEnableBiometric()) {
          if (await _biometric.authenticate(
            'Confirm to enable biometric unlock',
          )) {
            await _store.saveMasterKey(masterKey);
          }
        }
      }

      VaultSession.instance.unlock(masterKey);
    } on VaultException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not unlock. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _askEnableBiometric() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable biometric unlock?'),
        content: const Text(
          'Use your fingerprint or face to unlock the vault next time, '
          'instead of typing your PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _forgetBiometric() async {
    final ok = await confirmAction(
      context,
      title: 'Forget biometric unlock?',
      message:
          'The saved key on this device will be forgotten. You will need '
          'your vault PIN to unlock next time.',
      confirmLabel: 'Forget',
      destructive: true,
    );
    if (!ok) return;
    await _store.clear();
    if (mounted) setState(() => _biometricEnabled = false);
  }

  Future<void> _confirmSignOut() async {
    final ok = await confirmAction(
      context,
      title: 'Sign out?',
      message:
          'You will need your login password and vault PIN to sign back in.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (ok) await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock vault'),
        actions: [
          IconButton(
            onPressed: _confirmSignOut,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Enter your vault PIN',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  if (_biometricEnabled) ...[
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _unlockWithBiometrics,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Unlock with biometrics'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    enabled: !_loading,
                    onSubmitted: (_) => _unlockWithPin(),
                    decoration: const InputDecoration(
                      labelText: 'PIN or passphrase',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _unlockWithPin,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Unlock'),
                    ),
                  ),
                  if (_biometricEnabled)
                    TextButton(
                      onPressed: _loading ? null : _forgetBiometric,
                      child: const Text('Forget biometric unlock'),
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
