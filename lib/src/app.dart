import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:archespace_mobile/src/features/auth/data/auth_service.dart';
import 'package:archespace_mobile/src/features/vault/data/secure_key_store.dart';
import 'package:archespace_mobile/src/features/vault/data/vault_service.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/features/vault/presentation/inactivity_locker.dart';
import 'package:archespace_mobile/src/features/auth/presentation/login_screen.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/spaces_screen.dart';
import 'package:archespace_mobile/src/features/settings/application/appearance_controller.dart';
import 'package:archespace_mobile/src/features/vault/presentation/unlock_screen.dart';
import 'package:archespace_mobile/src/features/vault/presentation/vault_setup_screen.dart';
import 'package:archespace_mobile/src/shared/data/cache_store.dart';

class ArcheApp extends StatelessWidget {
  const ArcheApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = AppearanceController.instance;
    return ListenableBuilder(
      listenable: appearance,
      builder: (context, _) => MaterialApp(
        title: 'ArcheSpace',
        themeMode: appearance.themeMode,
        theme: ThemeData(
          colorSchemeSeed: appearance.accent,
          brightness: Brightness.light,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: appearance.accent,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const _RootGate(),
      ),
    );
  }
}

/// Decides which screen to show: login (no session), unlock (session but locked
/// vault), or the spaces list (session + unlocked). Locks the vault on sign-out.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  final AuthService _auth = AuthService();
  late final StreamSubscription<AuthState> _sub;

  @override
  void initState() {
    super.initState();
    _sub = _auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        VaultSession.instance.lock();
        // Don't leave a stored key or cached data behind for the next account.
        SecureKeyStore().clear();
        CacheStore.clear();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentSession == null) {
      return const LoginScreen();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: VaultSession.instance.unlocked,
      builder: (context, unlocked, _) => unlocked
          ? const InactivityLocker(child: SpacesScreen())
          : const _VaultGate(),
    );
  }
}

/// A signed-in but locked user either has an existing vault (show the unlock
/// screen) or is brand new (show first-run vault setup). Checks once per gate.
class _VaultGate extends StatefulWidget {
  const _VaultGate();

  @override
  State<_VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<_VaultGate> {
  late final Future<bool> _hasVault;

  @override
  void initState() {
    super.initState();
    final userId = AuthService().currentUser?.id;
    _hasVault = userId == null
        ? Future<bool>.value(true)
        : VaultService().hasVault(userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasVault,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // On error, assume a vault exists and fall back to the unlock screen
        // rather than risk overwriting one with a fresh setup.
        final needsSetup = snapshot.data == false;
        return needsSetup ? const VaultSetupScreen() : const UnlockScreen();
      },
    );
  }
}
