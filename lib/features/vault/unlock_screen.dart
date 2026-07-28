import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/vault/vault_service.dart';
import '../../core/vault/vault_session.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final AuthService _auth = AuthService();
  final VaultService _vault = VaultService();
  final TextEditingController _pin = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final masterKey = await _vault.unlock(userId, _pin.text.trim());
      VaultSession.instance.unlock(masterKey);
      // The root gate is listening to VaultSession.unlocked -> spaces screen.
    } on VaultException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not unlock. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock vault'),
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
                  TextField(
                    controller: _pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    enabled: !_loading,
                    onSubmitted: (_) => _unlock(),
                    decoration: const InputDecoration(
                      labelText: 'PIN or passphrase',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _unlock,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
