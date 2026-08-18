import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:archespace_mobile/src/shared/config/build_info.dart';

import 'package:archespace_mobile/src/features/auth/data/auth_service.dart';
import 'package:archespace_mobile/src/features/backup/data/backup_repository.dart';
import 'package:archespace_mobile/src/features/settings/application/appearance_controller.dart';
import 'package:archespace_mobile/src/features/vault/application/auto_lock_controller.dart';
import 'package:archespace_mobile/src/features/settings/presentation/account_security_screens.dart';
import 'package:archespace_mobile/src/features/storage/presentation/storage_screen.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/features/vault/data/biometric_service.dart';
import 'package:archespace_mobile/src/features/vault/data/secure_key_store.dart';
import 'package:archespace_mobile/src/shared/widgets/confirm_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();
  final SecureKeyStore _store = SecureKeyStore();
  final BiometricService _biometric = BiometricService();
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final available = await _biometric.isAvailable();
    final enabled = await _store.hasKey();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _enableBiometric() async {
    final ok = await _biometric.authenticate(
      'Confirm to enable biometric unlock',
    );
    if (!ok) return;
    await _store.saveMasterKey(VaultSession.instance.masterKey);
    if (!mounted) return;
    setState(() => _biometricEnabled = true);
    _snack('Biometric unlock enabled.');
  }

  void _lock() {
    VaultSession.instance.lock();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _pickAutoLock() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Auto-lock after inactivity',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final o in kAutoLockOptions)
              ListTile(
                title: Text(o.label),
                trailing: o.id == AutoLockController.instance.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(sheetContext, o.id),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await AutoLockController.instance.setId(selected);
      if (mounted) _snack('Auto-lock updated.');
    }
  }

  Future<void> _disableBiometric() async {
    final ok = await confirmAction(
      context,
      title: 'Disable biometric unlock?',
      message:
          'The saved key on this device will be forgotten. You will need '
          'your vault PIN to unlock next time.',
      confirmLabel: 'Disable',
      destructive: true,
    );
    if (!ok) return;
    await _store.clear();
    if (!mounted) return;
    setState(() => _biometricEnabled = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Biometric unlock disabled.')));
  }

  Future<void> _signOut() async {
    final ok = await confirmAction(
      context,
      title: 'Sign out?',
      message:
          'You will need your login password and vault PIN to sign back in.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!ok) return;
    await _auth.signOut();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _signOutAll() async {
    final ok = await confirmAction(
      context,
      title: 'Sign out of all devices?',
      message:
          'This ends your session on every device, including this one. You '
          'will need your login password and vault PIN to sign back in.',
      confirmLabel: 'Sign out everywhere',
      destructive: true,
    );
    if (!ok) return;
    await _auth.signOutAllDevices();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _exportBackup() async {
    try {
      final json = await BackupRepository(
        VaultSession.instance.masterKey,
      ).exportJson();
      final bytes = Uint8List.fromList(utf8.encode(json));
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save backup',
        fileName: 'arche-backup-$date.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );
      if (path != null) _snack('Backup saved.');
    } catch (_) {
      _snack("Couldn't export the backup.");
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final text = await File(path).readAsString();
      final count = await BackupRepository(
        VaultSession.instance.masterKey,
      ).importJson(text);
      _snack('Imported $count ${count == 1 ? 'item' : 'items'}.');
    } on FormatException {
      _snack("That backup file isn't valid.");
    } catch (_) {
      _snack("Couldn't import the backup.");
    }
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
            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: const Text('Change email'),
              subtitle: const Text('Update your email address'),
              onTap: () => _push(const ChangeEmailScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Change login password'),
              subtitle: const Text(
                'Used to sign in, separate from your vault PIN',
              ),
              onTap: () => _push(const ChangePasswordScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Two-factor authentication'),
              subtitle: const Text('Add an authenticator code at sign-in'),
              onTap: () => _push(const TwoFactorScreen()),
            ),
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete account',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text('Permanently delete your account and data'),
              onTap: () => _push(const DeleteAccountScreen()),
            ),
            const _SectionHeader('Appearance'),
            const _AppearanceSection(),
            const _SectionHeader('Backup'),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Export backup'),
              subtitle: const Text('Save all your spaces and items to a file'),
              onTap: _exportBackup,
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Import backup'),
              subtitle: const Text(
                'Restore spaces and items from a backup file',
              ),
              onTap: _importBackup,
            ),
            const _SectionHeader('Storage'),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const StorageScreen(mode: StorageMode.archive),
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
              leading: const Icon(Icons.pin_outlined),
              title: const Text('Change vault PIN'),
              subtitle: const Text('Unlocks your encrypted data'),
              onTap: () => _push(const ChangePinScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.lock_reset_outlined),
              title: const Text('Reset PIN with recovery code'),
              subtitle: const Text('Forgot your PIN? Use your recovery code'),
              onTap: () => _push(const ResetPinScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.vpn_key_outlined),
              title: const Text('Recovery code'),
              subtitle: const Text('Create or replace your recovery code'),
              onTap: () => _push(const SetupRecoveryScreen()),
            ),
            ListenableBuilder(
              listenable: AutoLockController.instance,
              builder: (context, _) {
                final option = kAutoLockOptions.firstWhere(
                  (o) => o.id == AutoLockController.instance.id,
                  orElse: () => kAutoLockOptions.last,
                );
                return ListTile(
                  leading: const Icon(Icons.lock_clock_outlined),
                  title: const Text('Auto-lock'),
                  subtitle: Text('Lock after inactivity · ${option.label}'),
                  onTap: _pickAutoLock,
                );
              },
            ),
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
              )
            else if (_biometricAvailable)
              ListTile(
                leading: const Icon(Icons.fingerprint),
                title: const Text('Enable biometric unlock'),
                subtitle: const Text(
                  'Unlock with fingerprint or face next time',
                ),
                onTap: _enableBiometric,
              ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Sign out',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: _signOut,
            ),
            ListTile(
              leading: Icon(
                Icons.devices,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Sign out of all devices',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text('End your session on every device'),
              onTap: _signOutAll,
            ),
            const _BuildFooter(),
          ],
        ),
      ),
    );
  }
}

/// Shows the app version and the source commit this build was compiled from.
/// The commit hash links to GitHub so anyone can verify the running binary
/// against the audited, open-source code.
class _BuildFooter extends StatefulWidget {
  const _BuildFooter();

  @override
  State<_BuildFooter> createState() => _BuildFooterState();
}

class _BuildFooterState extends State<_BuildFooter> {
  TapGestureRecognizer? _tap;

  @override
  void initState() {
    super.initState();
    if (BuildInfo.isStamped) {
      _tap = TapGestureRecognizer()..onTap = _openCommit;
    }
  }

  @override
  void dispose() {
    _tap?.dispose();
    super.dispose();
  }

  Future<void> _openCommit() async {
    await launchUrl(
      Uri.parse(BuildInfo.commitUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.color?.withValues(alpha: 0.7);
    final baseStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: muted);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      child: Center(
        child: Text.rich(
          TextSpan(
            style: baseStyle,
            children: [
              TextSpan(text: 'ArcheSpace v${BuildInfo.appVersion}  ·  build '),
              TextSpan(
                text: BuildInfo.buildHash,
                style: baseStyle?.copyWith(
                  fontFamily: 'monospace',
                  decoration: BuildInfo.isStamped
                      ? TextDecoration.underline
                      : null,
                  color: BuildInfo.isStamped
                      ? Theme.of(context).colorScheme.primary
                      : muted,
                ),
                recognizer: _tap,
              ),
            ],
          ),
          textAlign: TextAlign.center,
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
                    child: Tooltip(
                      message: option.description,
                      excludeFromSemantics: true,
                      child: Semantics(
                        button: true,
                        selected: appearance.accentId == option.id,
                        label: '${option.name}. ${option.description}',
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
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
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
