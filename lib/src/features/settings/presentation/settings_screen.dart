import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/auth/data/auth_service.dart';
import 'package:archespace_mobile/src/features/settings/application/appearance_controller.dart';
import 'package:archespace_mobile/src/features/storage/presentation/storage_screen.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/features/vault/data/secure_key_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();
  final SecureKeyStore _store = SecureKeyStore();
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _store.hasKey().then((has) {
      if (mounted) setState(() => _biometricEnabled = has);
    });
  }

  void _lock() {
    VaultSession.instance.lock();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _disableBiometric() async {
    await _store.clear();
    if (!mounted) return;
    setState(() => _biometricEnabled = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Biometric unlock disabled.')),
    );
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.currentUser?.email;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            const _SectionHeader('Account'),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Signed in as'),
              subtitle: Text(email ?? 'Unknown'),
            ),
            const _SectionHeader('Appearance'),
            const _AppearanceSection(),
            const _SectionHeader('Storage'),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StorageScreen(mode: StorageMode.archive),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Recycle bin'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StorageScreen(mode: StorageMode.bin),
                ),
              ),
            ),
            const _SectionHeader('Security'),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Lock vault'),
              subtitle: const Text('Require your PIN or biometrics again'),
              onTap: _lock,
            ),
            if (_biometricEnabled)
              ListTile(
                leading: const Icon(Icons.fingerprint),
                title: const Text('Disable biometric unlock'),
                subtitle: const Text('Forget the saved key on this device'),
                onTap: _disableBiometric,
              ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              title: Text(
                'Sign out',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: _signOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final appearance = AppearanceController.instance;
    return ListenableBuilder(
      listenable: appearance,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {appearance.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    appearance.setThemeMode(selection.first),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                for (final option in kAccentOptions)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => appearance.setAccent(option.id),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: option.color,
                          border: Border.all(
                            color: appearance.accentId == option.id
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: appearance.accentId == option.id
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
